defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble file archive, Solr archive and analytics.

  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  - `sync/0`, `sync/1`: sync Lastfm scrobble data to local filesystem
  - `transform_archive/2`: transform downloaded raw data and create a TSV file archive
  - `load_archive/2`: load all (TSV) data from the archive into Solr

  """

  alias LastfmArchive.Archive.FileArchive
  alias LastfmArchive.Archive.Transformers.FileArchiveTransformer
  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi
  alias LastfmArchive.Utils

  @path_io Application.compile_env(:lastfm_archive, :path_io, Elixir.Path)

  @type metadata :: LastfmArchive.Archive.Metadata.t()
  @type time_range :: {integer, integer}
  @type solr_url :: atom | Hui.URL.t()

  @type transform_options :: LastfmArchive.Behaviour.Archive.transform_options()

  @doc """
  Returns the total playcount and registered, i.e. earliest scrobble time for a user.
  """
  defdelegate info, to: LastfmClient

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

  - `:interval` - default `1000`(ms), the duration between successive Lastfm API requests.
  This provides a control for request rate.
  The default interval ensures a safe rate that is
  within Lastfm's term of service: no more than 5 requests per second

  - `:overwrite` - default `false` (not available currently), if sets to true
  the system will (re)fetch and overwrite any previously downloaded
  data. Use this option to refresh the file archive. Otherwise (false),
  the system will not be making calls to Lastfm to check and re-fetch data
  if existing data chunks / pages are found. This speeds up archive updating

  - `:per_page` - default `200`, number of scrobbles per page in archive. The default is the
  max number of tracks per request permissible by Lastfm

  - `:data_dir` - default `lastfm_data`. The file archive is created within a main data directory,
  e.g. `./lastfm_data/a_lastfm_user/`.

  These options can be configured in `config/config.exs`:

  ```
    config :lastfm_archive,
      ...
      data_dir: "./lastfm_data/"
  ```
  """
  @spec sync(binary, keyword) :: {:ok, metadata()} | {:error, :file.posix()}
  def sync(user \\ LastfmClient.default_user(), options \\ []) do
    user
    |> metadata()
    |> Archive.impl().archive(options, LastfmApi.new())
  end

  @doc """
  Read scrobbles from an archive of a Lastfm user.

  This returns scrobbles for a single day  or month period
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
  """
  @spec read(binary, FileArchive.read_options()) :: {:ok, Explorer.DataFrame} | {:error, term()}
  def read(user \\ LastfmClient.default_user(), options) do
    user
    |> metadata()
    |> Archive.impl().read(options)
  end

  @doc """
  Read scrobbles data from an Apache Parquet archive created via `transform/2`.

  Returns a data frame containing scrobbles spanning a single year.

  ### Example
  ```
    # read a year of scrobbles for a user
    LastfmArchive.read_parquet("a_lastfm_user", year: 2023)
  ```

  Options:
  - `:year` - read scrobbles for this particular year
  """
  @spec read_parquet(binary, DerivedArchive.read_options()) :: {:ok, Explorer.DataFrame} | {:error, term()}
  def read_parquet(user \\ LastfmClient.default_user(), year: year) do
    user
    |> metadata(:derived_archive, format: :parquet)
    |> Archive.impl(:derived_archive).read(year: year)
  end

  @doc """
  Read scrobbles data from a TSV archive created via `transform/2`

  Returns a data frame containing scrobbles spanning a single year.

  ### Example
  ```
    # read a year of scrobbles for a user
    LastfmArchive.read_tsv("a_lastfm_user", year: 2023)
  ```

  Options:
  - `:year` - read scrobbles for this particular year
  """
  @spec read_tsv(binary, DerivedArchive.read_options()) :: {:ok, Explorer.DataFrame} | {:error, term()}
  def read_tsv(user \\ LastfmClient.default_user(), year: year) do
    user
    |> metadata(:derived_archive, format: :tsv)
    |> Archive.impl(:derived_archive).read(year: year)
  end

  @doc """
  Transform downloaded file archive into TSV or Apache Parquet formats for a Lastfm user.

  ### Example

  ```
    LastfmArchive.transform("a_lastfm_user", format: :tsv)

    # transform archive of the default user into TSV files
    LastfmArchive.transform()
  ```

  Current output transform formats: `:tsv`, `:parquet`.

  The function only transforms downloaded archive data on local filesystem. It does not fetch data from Lastfm,
  which can be done via `sync/2`.

  The transformed files are created on a yearly basis and stored in `gzip` compressed format.
  They are stored in a `tsv` or `parquet` directory within either the default `./lastfm_data/`
  or the directory specified in config/config.exs (`:lastfm_archive, :data_dir`).
  """
  @spec transform(binary, transform_options) :: any
  def transform(user \\ LastfmClient.default_user(), options \\ [format: :tsv])

  def transform(user, [format: format] = options) when is_binary(user) and format in [:tsv, :parquet] do
    user
    |> metadata(:derived_archive, options)
    |> update_metadata(:derived_archive, options)
    |> do_transform(options)
    |> update_metadata(:derived_archive, options)
  end

  defp do_transform({:ok, metadata}, options) do
    {:ok, metadata} = Archive.impl(:derived_archive).after_archive(metadata, FileArchiveTransformer, options)
    metadata
  end

  defp metadata(user, archive_type \\ :file_archive, options \\ [])

  defp metadata(user, archive_type, options) do
    {:ok, metadata} = user |> Archive.impl(archive_type).describe(options)
    metadata
  end

  defp update_metadata(metadata, archive_type, options) do
    Archive.impl(archive_type).update_metadata(metadata, options)
  end

  # return all archive file paths in a list
  defp ls_archive_files(user) do
    Path.join(Utils.user_dir(user), "**/*.gz")
    |> @path_io.wildcard([])
    |> Enum.map(&(String.split(&1 |> to_string, user <> "/") |> tl |> hd))
  end

  @doc """
  Load all TSV data from the archive into Solr for a Lastfm user.

  The function finds TSV files from the archive and sends them to
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

  TSV files must be pre-created before the loading - see
  `transform_archive/2`.
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

    for tsv_file <- archive_files, String.match?(tsv_file, ~r/^tsv/) do
      IO.puts("Loading #{tsv_file} into Solr")
      {status, _resp} = LastfmArchive.Load.load_solr(url, user, tsv_file)
      IO.puts("#{status}\n")
    end

    :ok
  end
end
