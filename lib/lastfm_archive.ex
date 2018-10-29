defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble data archive and analytics.
  
  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  
  - `archive/0`, `archive/2`, `archive3`: download raw Lastfm scrobble data to local filesystem.

  """
  # pending, with stop gap functions for `LastfmArchive.Extract.get_recent_tracks`,
  # `LastfmArchive.Extract.get_info`
  # until Elixirfm pull requests are resolved
  # import Elixirfm.User

  import LastfmArchive.Extract

  @type date_range :: :all

  @default_data_dir "./lastfm_data/"
  @default_opts %{"interval" => 500, "per_page" => 200, "overwrite" => false}
  @no_scrobble_log_filenmae ".no_scrobble"

  @doc """
  Download all scrobbled tracks and create an archive on local filesystem for the default user.

  ### Example

  ```
    LastfmArchive.archive
  ```

  The archive belongs to a default user specified in configuration, for example `user_a` (in
  `config/config.exs`):

  ```
    config :lastfm_archive,
      user: "user_a",
      ... # other archiving options
  ```

  See `archive/2` for further details on archive format, file location and archiving options
  """
  @spec archive :: :ok | {:error, :file.posix}
  def archive do
    user = Application.get_env(:lastfm_archive, :user) || raise "User not found in configuration"
    archive(user)
  end

  @doc """
  Download all scrobbled tracks and create an archive on local filesystem for a Lastfm user.

  ### Example

  ```
    LastfmArchive.archive("a_lastfm_user")

    # with archiving option
    LastfmArchive.archive("a_lastfm_user", interval: 300) # 300ms interval between Lastfm API requests
    LastfmArchive.archive("a_lastfm_user", overwrite: true) # re-fetch / overwrite downloaded data
  ```

  Older scrobbles are archived on a yearly basis, whereas the latest (current year) scrobbles
  are extracted on a daily basis to ensure data immutability and updatability.

  The data is currently in raw Lastfm `recenttracks` JSON format, chunked into
  200-track (max) `gzip` compressed pages and stored within directories corresponding
  to the years and days when tracks were scrobbled.

  Options:
  
  - `:interval` the duration (in milliseconds) between successive requests
  sent to Lastfm API. It provides a control of the max rate of requests.
  **Default is 500** (ms), this ensures a safe rate that is
  within Lastfm's term of service  - no more than 5 requests per second

  - `:overwrite` if `true`, fetch and overwrite any previously downloaded
  data. Use this option to refresh the file archive. **Default is false**
  if existing data chunks / pages are found, the system will not be making
  calls to Lastfm to re-fetch data

  - `:per_page` number of scrobbles per page in archive. The default is 200 -
  max number of tracks per request permissible by Lastfm API

  The data is written to a main directory,
  e.g. `./lastfm_data/a_lastfm_user/` as configured in
  `config/config.exs`:

  ```
    config :lastfm_archive,
      ...
      data_dir: "./lastfm_data/"
  ```

  See `archive/3` for archiving data within a date range.

  ### Reruns and refresh archive
  Lastfm API calls could timed out occasionally. When this happen
  the function will continue archiving and move on to the next data chunk (page).
  It will log the missing page event(s) in an `error` directory. 
  
  Rerun the function
  to download any missing data chunks. The function skips all existing
  archived pages by default so that it will not make repeated calls to Lastfm.
  Use the `overwrite: true` option to re-fetch existing data.

  To create a fresh or refresh part of the archive: delete all or some
  files in the archive and re-run the function, or use the `overwrite: true`
  option.
  """
  @spec archive(binary, keyword) :: :ok | {:error, :file.posix}
  def archive(user, options) when is_list(options), do: archive(user, :all, options)

  @doc """
  Download scrobbled tracks within a date range and create an archive on local filesystem for a Lastfm user.
  
  Supported date range:
  
  - `:all` archive all scrobble data in yearly and daily (current year) batches
  - other date range: forthcoming
  
  """
  @spec archive(binary, date_range, keyword) :: :ok | {:error, :file.posix}
  def archive(user, date_range \\ :all, options \\ []) 
  def archive(user, :all, options) do
    {playcount, registered} = info(user)

    # interval between requests cf. Lastfm API request max rate limit
    interval = option(options, :interval)

    IO.puts "Archiving #{playcount} scrobbles for #{user}"

    now = DateTime.utc_now
    last_year_s = (now.year - 1) |> to_string 
    {_, last_year_dt, _} = last_year_s <> "-01-01T00:00:00Z" |> DateTime.from_iso8601
    batches = year_range(registered, last_year_dt |> DateTime.to_unix)

    # archive data in yearly batches until the previous year
    for {from, to} <- batches do
      from_s = from |> date_string_from_unix
      to_s = to |> date_string_from_unix

      IO.puts "\nyear: #{from_s} - #{to_s}"
      _archive(user, {from, to}, options)

      IO.puts ""
      :timer.sleep(interval) # prevent request rate limit (max 5 per sec) from being reached
    end

    # Lastfm API paging chunks from the latest tracks, any new scrobbles would swifts tracks
    # among fixed-size pages -> all downloaded pages for the entire year would need to be updated
    #
    # extracting data in daily timeframes would ensure data immutability/integrity of downloaded pages,
    # enabling easier/fastest/real-time archive syncing and new scrobbles updating
    #
    # archive data in daily batches for this year
    {_, new_year_d} = Date.new(now.year, 1, 1)
    this_year_day_range = Date.range(new_year_d, Date.utc_today)
    this_year_s = new_year_d.year |> to_string
    overwrite = option(options, :overwrite)

    IO.puts "\nyear: #{this_year_s}"

    no_scrobble_dates_l = no_scrobble_dates(user, this_year_s)

    for day <- this_year_day_range do
      day_s = day |> Date.to_string
      {_, dt1, _} = "#{day_s}T00:00:00Z" |> DateTime.from_iso8601
      {_, dt2, _} = "#{day_s}T23:59:59Z" |> DateTime.from_iso8601

      file_path = day_s |> String.split("-") |> Path.join
      extracted_day? = File.dir? Path.join(user_data_dir(user), file_path)
      checked_no_scrobble_day? = Enum.member? no_scrobble_dates_l, file_path

      if (not(extracted_day?) and not(checked_no_scrobble_day?)) or overwrite do
        daily = true
         _archive(user, {dt1 |> DateTime.to_unix, dt2 |> DateTime.to_unix}, options, daily)
        :timer.sleep(interval)
      end
    end
    :ok
  end

  defp _archive(user, date_range_unix, options, daily \\ false)

  # daily batch archiving
  defp _archive(user, {from, to}, options, true) do
    playcount = info(user, {from, to}) |> String.to_integer
    per_page = option(options, :per_page)
    total_pages = (playcount / per_page) |> :math.ceil |> round

    unless playcount == 0 do
      IO.puts "\n#{date_string_from_unix(from)}"
      IO.puts "#{playcount} scrobbles"

      daily = true
      for page <- 1..total_pages do
        # starting from the last page - earliest scrobbles
        fetch_page = total_pages - (page - 1)
        _archive(user, {from, to, fetch_page}, options, daily)
      end
    else
      dt = from |> DateTime.from_unix!
      file_path =  dt |> path_from_datetime
      year_s = dt.year |> to_string
      log_no_scrobble(user, year_s, file_path)
    end
  end

  # yearly batch archiving
  defp _archive(user, {from, to}, options, daily) do
    playcount = info(user, {from, to}) |> String.to_integer
    per_page = option(options, :per_page)
    total_pages = (playcount / per_page) |> :math.ceil |> round

    IO.puts "#{playcount} scrobbles"
    IO.puts "#{total_pages} pages - #{per_page} scrobbles each"

    for page <- 1..total_pages do
      # starting from the last page - earliest scrobbles
      fetch_page = total_pages - (page - 1)
      _archive(user, {from, to, fetch_page}, options, daily)
    end
  end

  defp _archive(user, {from, to, page}, options, daily) do
    dt = from |> DateTime.from_unix!
    interval = option(options, :interval)
    per_page = option(options, :per_page)
    overwrite = option(options, :overwrite)

    filename = if daily do
      dt
      |> path_from_datetime
      |> Path.join(Enum.join(["#{per_page}", "_", page |> to_string]))
    else
      year_s = dt.year |> to_string
      year_s |> Path.join(Enum.join(["#{per_page}", "_", page |> to_string]))
    end

    if not(file_exists?(user, filename)) or overwrite do
      data = extract(user, page, per_page, from, to)
      write(user, data, filename)
      IO.write "."
      :timer.sleep(interval)
    end
  end

  defp file_exists?(user, filename) do
    file_path = Path.join("#{user_data_dir(user)}", "#{filename}.gz")
    File.exists? file_path
  end

  # provide a year range (first day, last day) tuple in Unix time for a particular year
  @doc false
  def year_range(year) when is_binary(year) do
    {_, d0, _} = "#{year}-01-01T00:00:00Z" |> DateTime.from_iso8601
    {_, d1, _} = "#{year}-12-31T23:59:59Z" |> DateTime.from_iso8601
    {d0 |> DateTime.to_unix, d1 |> DateTime.to_unix}
  end

  # provides a list of year range (first day, last day) tuples in Unix time
  # starting from the user registration date - last year
  @doc false
  def year_range(t1, t2) when is_integer(t1) and is_integer(t2) do
    d1 = DateTime.from_unix!(t1)
    y1 = d1.year

    d2 = DateTime.from_unix!(t2)
    y2 = d2.year
    for year <- y1..y2, do: year_range(year |> to_string)
  end

  defp date_string_from_unix(dt), do: dt |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string

  defp path_from_datetime(dt), do: dt |> DateTime.to_date |> Date.to_string |> String.split("-") |> Path.join

  defp user_data_dir(user), do: (Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir) |> Path.join(user)

  # the option provided through keyword list, config or system default
  defp option(options, key) when is_list(options) and is_atom(key) do
    option = Keyword.get(options, key)
    if option, do: option, else: Application.get_env(:lastfm_archive, key) || @default_opts[key |> to_string]
  end

  defp no_scrobble_dates(user, year) do
    no_scrobble_log_path =  Path.join [user_data_dir(user), year, @no_scrobble_log_filenmae]
    unless (File.exists? no_scrobble_log_path) do
      file_dir = Path.dirname no_scrobble_log_path
      unless File.exists?(file_dir), do: File.mkdir_p file_dir
      File.write!(no_scrobble_log_path, "no_scrobble")
    end
    File.read!(no_scrobble_log_path) |> String.split(",")
  end

  defp log_no_scrobble(user, year, file_path) do
    no_scrobble_log_path =  Path.join [user_data_dir(user), year, @no_scrobble_log_filenmae]
    no_scrobble_log = File.read!(no_scrobble_log_path)
    unless String.match?(no_scrobble_log, ~r/#{file_path}/) do
      File.write!(no_scrobble_log_path, ",#{file_path}", [:append])
    end
  end

end
