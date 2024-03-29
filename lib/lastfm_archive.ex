defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for extracting and archiving Last.fm music listening data - scrobbles.

  Current usage:
  - `sync/0`, `sync/2`: create and sync Lastfm scrobble data to local file archives
  - `transform/0`, `transform/2`: transform downloaded raw data in file archives into columnar and other formats, e.g. CSV, Apache Parquet, Arrow
  - `read/2`: load daily, monthly, yearly and entire dataset from file archives into data frames
  - `load_archive/2`: load all CSV data from the archive into Solr

  """

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi

  import LastfmArchive.Archive.Transformers.Transformer, only: [transformer: 1]
  import LastfmArchive.Archive.Transformers.TransformerConfigs, only: [default_opts: 0]
  import LastfmArchive.Utils.Archive, only: [check_existing_archive: 2]

  @facets LastfmArchive.Archive.Transformers.TransformerConfigs.facets()
  @path_io Application.compile_env(:lastfm_archive, :path_io, Elixir.Path)

  @type metadata :: Metadata.t()
  @type time_range :: {integer, integer}
  @type solr_url :: atom | Hui.URL.t()

  @type options :: LastfmArchive.Behaviour.Archive.options()

  @doc """
  Returns the total playcount and registered, i.e. earliest scrobble time for a user.
  """
  defdelegate info, to: LastfmClient

  @doc """
  Returns the default coofigured Lastfm user
  """
  defdelegate default_user, to: LastfmClient

  @doc """
  Sync scrobbles for a Lastfm user.

  ### Example

  ```
    LastfmArchive.sync("a_lastfm_user")
  ```

  You can also specify a default user is in configuration,
  for example `user_a` in `config/config.exs`:

  ```
    config :lastfm_archive,
      user: "user_a",
      ... # other archiving options
  ```

  And run:

  ```
    LastfmArchive.sync
  ```

  The first sync downloads all daily scrobbles in 200-track (gzip compressed)
  chunks that are written into a local file archive. Subsequent syncs extract
  further scrobbles starting from the date of latest downloaded scrobbles.

  The data is currently in raw Lastfm `recenttracks` JSON format, chunked into
  200-track (max) `gzip` compressed pages and stored within directories corresponding
  to the days when tracks were scrobbled.

  Options:

  - `:data_dir` - default `lastfm_data`, file archives are stored within this directory

  - `:date` - archive scrobbles from this date only

  - `:interval` - default `1000`(ms), the duration between successive Lastfm API requests.
  This default interval ensures a safe request rate that is
  within Lastfm's term of service: no more than 5 requests per second

  - `:overwrite` - default `false`, if sets to true
  the tool will (re)fetch and overwrite any previously downloaded
  data. Use this option to refresh the file archive. Otherwise (false),
  the system will not be making calls to Lastfm to re-fetch data
  if existing data chunks / pages are found.

  - `:per_page` - default `200`, number of scrobbles per file. The default is the
  max number of tracks per request permissible by Lastfm

  - `:year` - archive scrobbles from this year only

  `:interval`, `:per_page` and `:data_dir` options can be configured in `config/config.exs`:

  ```
    config :lastfm_archive,
      ...
      data_dir: "./lastfm_data/"
  ```

  """
  @spec sync(binary(), keyword()) :: {:ok, metadata()} | {:error, :file.posix()}
  def sync(user \\ default_user(), options \\ []) do
    user
    |> impl().describe(options)
    |> then(fn {:ok, metadata} -> impl().archive(metadata, options, LastfmApi.new()) end)
  end

  @doc """
  Convenient update function to sync the latest scrobbles and transforms them into existing faceted archives.

  Options:
  - `:year` - limit sync to this particular year, default: the current year
  - `:format` - transform archive format: `:csv`, `:parquet`, `:ipc`, `:ipc_stream` (default)
  """
  @spec update_latest(binary(), keyword()) :: list({:ok, metadata()} | {:error, :archive_not_found})
  def update_latest(user \\ default_user(), options \\ []) do
    year = Keyword.get(options, :year, this_year())
    overwrite = Keyword.get(options, :overwrite, true)

    options =
      Keyword.validate!(options, default_opts())
      |> Keyword.put(:year, year)
      |> Keyword.put(:overwrite, overwrite)

    sync_resp =
      with {:ok, _} <- check_existing_archive(user, Keyword.delete(options, :format)) do
        sync(user, year: year)
      end

    transform_resp =
      for facet <- @facets do
        options = Keyword.put(options, :facet, facet)

        with {:ok, _} <- check_existing_archive(user, options) do
          transform(user, options)
        end
      end

    [sync_resp] ++ transform_resp
  end

  defp this_year(), do: Date.utc_today().year

  @doc """
  Read from an archive of a Lastfm user.

  This returns scrobbles for a single day or month period
  in a lazy Explorer.DataFrame for further data manipulation
  and visualisation.

  ### Example
  ```
    # read a single-day scrobbles from the configured
    # archive (FileArchive) and default user
    LastfmArchive.read(day: ~D[2022-12-31])

    # read a single-month scrobbles for a user
    LastfmArchive.read("a_lastfm_user",  month: ~D[2022-12-31])
  ```

  Options:
  - `:day` - read scrobbles for this particular date (`Date.t()`)
  - `:month` - read scrobbles for this particular month (`Date.t()`)

  This function can also return a lazy data frame from derived archive.
  i.e. CSV, Parquet archives created via `transform/2`.

  ### Example
  ```
    # read a single year of scrobbles for a user from Parquet archive
    LastfmArchive.read("a_lastfm_user", format: :parquet, year: 2023)

    # read everything for a user from Parquet archive
    LastfmArchive.read("a_lastfm_user", format: :parquet)
  ```

  Options:
  - `:format` - derived archive format: `:csv`, `:parquet`, `:ipc`, `:ipc_stream` (default)
  - `:facet` - type of archive: `:scrobbles` (default), `:albums`, `:artists` or `:tracks`
  - `:year` - only read scrobbles for this particular year (default - all years)
  - `:columns` - an atom list for retrieving only a columns subset, available columns:
  #{%LastfmArchive.Archive.Scrobble{} |> Map.keys() |> List.delete(:__struct__) |> Enum.map_join(", ", &(("`:" <> Atom.to_string(&1)) <> "`"))}
  """
  @spec read(binary(), keyword()) :: {:ok, Explorer.DataFrame} | {:error, term()}
  def read(user \\ default_user(), options) do
    user
    |> impl(options).describe(options)
    |> then(fn {:ok, metadata} -> impl(options).read(metadata, options) end)
  end

  @doc """
  Transform downloaded file archive into CSV or Apache Parquet formats for a Lastfm user.

  ### Example

  ```
    LastfmArchive.transform("a_lastfm_user", format: :csv)

    # transform archive of the default user into CSV files
    LastfmArchive.transform()
  ```

  The function only transforms downloaded archive data on local filesystem. It does not fetch data from Lastfm,
  which can be done via `sync/2`.

  The transformed files are created on a yearly basis and stored in `gzip` compressed format.
  They are stored in a `csv` or `parquet` directory within either the default `./lastfm_data/`
  or the directory specified in config/config.exs (`:lastfm_archive, :data_dir`).

  Options:
  - `:format` - format into which file archive is transformed: `:csv`, `:parquet`, `:ipc`, `:ipc_stream` (default)
  - `:facet` - type of archive: `:scrobbles` (default), `:albums`, `:artists` or `:tracks`
  - `:overwrite` existing data, default: false
  - `:year` - transform data from this particular year
  """
  @spec transform(binary(), options) :: any
  def transform(user \\ default_user(), options \\ [])

  def transform(user, options) when is_binary(user) do
    options = Keyword.validate!(options, default_opts()) |> Enum.sort()
    facet = Keyword.get(options, :facet)

    with {:ok, facet} <- validate_facet(facet),
         {:ok, metadata} <- impl(options).describe(user, options),
         {:ok, metadata} <- impl(options).post_archive(metadata, transformer(facet), options) do
      impl(options).update_metadata(metadata, options)
    end
  end

  defp impl(options \\ []) do
    case Keyword.has_key?(options, :format) do
      true -> Archive.impl(:derived_archive)
      false -> Archive.impl(:file_archive)
    end
  end

  defp validate_facet(facet) when facet in @facets, do: {:ok, facet}
  defp validate_facet(_), do: {:error, :invalid_facet}

  # return all archive file paths in a list
  defp ls_archive_files(user, options \\ []) do
    LastfmArchive.Utils.Archive.user_dir(user, options)
    |> Path.join("**/*.gz")
    |> @path_io.wildcard([])
    |> Enum.map(&(String.split(&1 |> to_string, user <> "/") |> tl |> hd))
  end

  @doc """
  Load all CSV data from the archive into Solr for a Lastfm user.

  The function finds CSV files from the archive and sends them to
  Solr for ingestion one at a time. It uses `Hui` client to interact
  with Solr and the `t:Hui.URL.t/0` struct
  for Solr endpoint specification.

  ### Example

  ```
    # define a Solr endpoint with %Hui.URL{} struct
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "http://localhost:8983/solr/lastfm_archive", handler: "update", headers: headers}

    LastfmArchive.load_archive("a_lastfm_user", url)
  ```

  CSV files must be pre-created before the loading - see
  `transform/2`.
  """
  @spec load_archive(binary, solr_url) :: :ok | {:error, Hui.Error.t()}
  def load_archive(user, url) when is_atom(url) and url != nil do
    url_config = Application.get_env(:hui, url)
    url_struct = if url_config, do: struct(Hui.URL, url_config), else: nil
    load_archive(user, url_struct)
  end

  def load_archive(user, url) when is_map(url) do
    with {status1, _} <- LastfmArchive.Load.ping_solr(url.url),
         {status2, _} <- LastfmArchive.Load.check_solr_schema(url.url) do
      case {status1, status2} do
        {:ok, :ok} -> _load_archive(user, url)
        _ -> {:error, %Hui.Error{reason: :ehostunreach}}
      end
    end
  end

  def load_archive(_, _), do: {:error, %Hui.Error{reason: :einval}}

  defp _load_archive(user, url) do
    archive_files = ls_archive_files(user)

    for tsv_file <- archive_files, String.match?(tsv_file, ~r/^csv/) do
      IO.puts("Loading #{tsv_file} into Solr")
      {status, _resp} = LastfmArchive.Load.load_solr(url, user, tsv_file)
      IO.puts("#{status}\n")
    end

    :ok
  end
end
