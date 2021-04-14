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

  alias Lastfm.Archive
  alias LastfmArchive.{Cache, Utils}

  @default_opts %{
    interval: Application.get_env(:lastfm_archive, :interval, 500),
    per_page: Application.get_env(:lastfm_archive, :per_page, 200),
    reset: Application.get_env(:lastfm_archive, :reset, false),
    data_dir: Application.get_env(:lastfm_archive, :data_dir, "./archive_data/")
  }

  @api Application.get_env(:lastfm_archive, :lastfm_client)
  @archive Application.get_env(:lastfm_archive, :type, Lastfm.FileArchive)
  @cache Application.get_env(:lastfm_archive, :cache, LastfmArchive.Cache)

  @path_io Application.get_env(:lastfm_archive, :path_io)
  @file_io Application.get_env(:lastfm_archive, :file_io)

  @type archive :: Archive.t()
  @type time_range :: {integer, integer}
  @type solr_url :: atom | Hui.URL.t()

  @doc """
  Sync scrobbles of a default user specified in configuration.

  ### Example

  ```
    LastfmArchive.sync
  ```

  The default user is specified in configuration, for example `user_a` in
  `config/config.exs`:

  ```
    config :lastfm_archive,
      user: "user_a",
      ... # other archiving options

  ```

  See `sync/1` for further details and archiving options.
  """
  @spec sync :: :ok | {:error, :file.posix()}
  def sync do
    user = Application.get_env(:lastfm_archive, :user) || raise "User not found in configuration"
    sync(user)
  end

  @doc """
  Sync scrobbles for a Lastfm user.

  ### Example

  ```
    LastfmArchive.sync("a_lastfm_user")
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
  @spec sync(binary, keyword) :: :ok | {:error, :file.posix()}
  def sync(user, options \\ []) do
    @cache.load(user, @cache, options)
    {:ok, archive} = @archive.describe(user, options)
    sync_archive(archive, options)
  end

  defp sync_archive(%{identifier: user} = archive, options) do
    client = %Lastfm.Client{method: "user.getrecenttracks"}
    now = DateTime.utc_now() |> DateTime.to_unix()

    with {total, registered_time} <- @api.info(user, %{client | method: "user.getinfo"}),
         {_, last_scrobble_time} <- @api.playcount(user, {registered_time, now}, client),
         archive <- update_archive(archive, total, {registered_time, last_scrobble_time}),
         {:ok, archive} <- @archive.update_metadata(archive, options) do
      Utils.display_progress(archive)

      for year <- Utils.year_range(archive.temporal) do
        {from, to} = Utils.build_time_range(year)
        sync_archive(archive, {from, to, Cache.get({user, year})}, options)
        @cache.serialise(user, @cache, options)
      end

      @archive.update_metadata(%{archive | modified: DateTime.utc_now()}, options)
    else
      error -> error
    end
  end

  defp sync_archive(archive, time_range, options \\ [])

  defp sync_archive(%Archive{extent: 0}, _year_time_range, _options), do: :ok

  defp sync_archive(archive, {from, to, cache}, options) do
    client = %Lastfm.Client{method: "user.getrecenttracks"}
    options = Map.merge(@default_opts, Enum.into(options, @default_opts))
    year = DateTime.from_unix!(from).year
    time_ranges = Utils.build_time_range({from, to})

    for time_range <- time_ranges, within_range?(time_range, archive.temporal) do
      case Map.get(cache, time_range, %{}) do
        {playcount, _sync_results} ->
          Utils.display_skip_message(time_range, playcount)

        %{} ->
          :timer.sleep(options.interval)

          {playcount, _} = @api.playcount(archive.identifier, time_range, client)
          pages = (playcount / options.per_page) |> :math.ceil() |> round

          Utils.display_progress(time_range, playcount, pages)
          sync_results = sync_archive(archive, time_range, pages, options)

          @cache.put({archive.identifier, year}, time_range, {playcount, sync_results}, @cache)
      end
    end

    :ok
  end

  defp sync_archive(_archive, _time_range, 0, _options), do: [:ok]

  defp sync_archive(archive = %{identifier: user}, {from, to}, pages, options) do
    from_date = DateTime.from_unix!(from) |> DateTime.to_date()
    page_dir = Date.to_string(from_date) |> String.replace("-", "/")

    for page <- pages..1, pages > 0 do
      :timer.sleep(options.interval)

      page_num = page |> to_string |> String.pad_leading(3, "0")
      path = Path.join([page_dir, "#{options.per_page}_#{page_num}"])

      scrobbles =
        @api.scrobbles(user, {page - 1, options.per_page, from, to}, %Lastfm.Client{
          method: "user.getrecenttracks"
        })

      case @archive.write(archive, scrobbles, filepath: path) do
        :ok ->
          IO.write(".")
          :ok

        _error ->
          IO.write("x")
          {:error, %{user: user, page: page - 1, from: from, to: to, per_page: options.per_page}}
      end
    end
  end

  defp update_archive(archive, total, {registered_time, last_scrobble_time}) do
    %{
      archive
      | temporal: {registered_time, last_scrobble_time},
        extent: total,
        date: last_scrobble_time |> DateTime.from_unix!() |> DateTime.to_date()
    }
  end

  defp within_range?({from, to}, {registered_time, last_scrobble_time}) do
    from < last_scrobble_time and to > registered_time
  end

  @doc """
  Transform downloaded raw JSON data and create a TSV file archive for a Lastfm user.

  ### Example

  ```
    LastfmArchive.transform_archive("a_lastfm_user")
  ```

  The function only transforms downloaded archive data on local filesystem. It does not fetch data from Lastfm,
  which can be done via `archive/2`, `archive/3`. 

  The TSV files are created on a yearly basis and stored in `gzip` compressed format.
  They are stored in a `tsv` directory within either the default `./lastfm_data/`
  or the directory specified in config/config.exs (`:lastfm_archive, :data_dir`).

  """
  @spec transform_archive(binary, :tsv) :: :ok
  def transform_archive(user, _mode \\ :tsv) do
    raw_json_files = ls_archive_files(user)

    # group file paths by years, to create per-year TSV file archive
    archive_file_batches =
      Enum.group_by(raw_json_files, fn x ->
        x = Regex.run(~r/^\d{4}/, x)
        if is_nil(x), do: x, else: x |> hd
      end)

    :ok = Utils.create_tsv_dir(user)

    for {year, archive_files} <- archive_file_batches, year != nil do
      tsv_filepath = Path.join([Utils.user_dir(user), "tsv", "#{year}.tsv.gz"])

      if @file_io.exists?(tsv_filepath) do
        IO.puts("\nTSV file archive exists, skipping #{year} scrobbles.")
      else
        IO.puts("\nCreating TSV file archive for #{year} scrobbles.")
        write_tsv(user, tsv_filepath, archive_files)
      end
    end

    :ok
  end

  defp write_tsv(user, tsv_filepath, archive_files) do
    for archive_file <- archive_files, String.match?(archive_file, ~r/^\d{4}/) do
      @file_io.write(tsv_filepath, LastfmArchive.Transform.transform(user, archive_file), [:compressed])
    end
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
