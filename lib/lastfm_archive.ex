defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble data archive and analytics.
  
  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  
  - `archive/0`, `archive/2`: download all raw Lastfm scrobble data to local filesystem
  - `archive/3`: download a data subset within a date range

  """
  # pending, with stop gap functions for `LastfmArchive.Extract.get_recent_tracks`,
  # `LastfmArchive.Extract.get_info`
  # until Elixirfm pull requests are resolved
  # import Elixirfm.User

  import LastfmArchive.Extract

  @type date_range :: :all | :today | :yesterday | integer | Date.t | Date.Range.t

  @default_data_dir "./lastfm_data/"
  @default_opts %{"interval" => 500, "per_page" => 200, "overwrite" => false, "daily" => false}
  @no_scrobble_log_filenmae ".no_scrobble"

  @doc false
  defguard is_year(y) when is_integer(y) and y < 3000 and y > 2000

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
  
  - `:interval` - default `500`(ms), the duration between successive Lastfm API requests.
  This provides a control for request rate.
  The default interval ensures a safe rate that is
  within Lastfm's term of service: no more than 5 requests per second

  - `:overwrite` - default `false`, if sets to true
  the system will (re)fetch and overwrite any previously downloaded
  data. Use this option to refresh the file archive. Otherwise (false), 
  the system will not be making calls to Lastfm to check and re-fetch data
  if existing data chunks / pages are found. This speeds up archive updating

  - `:per_page` - default `200`, number of scrobbles per page in archive. The default is the
  max number of tracks per request permissible by Lastfm

  - `:daily` - default `false`, an option for archiving at daily granularity, entailing
  smaller and immutable archive files suitable for latest scrobbles data update

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

  ### Example

  ```
    LastfmArchive.archive("a_lastfm_user", :past_month)

    # data from year 2016
    LastfmArchive.archive("a_lastfm_user", 2016)

    # with Date struct
    LastfmArchive.archive("a_lastfm_user", ~D[2018-10-31])

    # with Date.Range struct
    d1 = ~D[2018-01-01]
    d2 = d1 |> Date.add(7)
    LastfmArchive.archive("a_lastfm_user", Date.range(d1, d2), daily: true, overwrite: true)
  ```

  Supported date range:

  - `:all`: archive all scrobble data between Lastfm registration date and now
  - `:today`, `:yesterday`, `:past_week`, `past_month` - other convenience date ranges
  - `yyyy` (integer): data for a single year
  - `Date`: data for a specific date - single day
  - `Date.Range`: data for a specific date range

  See `archive/2` for more details on archiving options.
  """
  @spec archive(binary, date_range, keyword) :: :ok | {:error, :file.posix}
  def archive(user, date_range \\ :all, options \\ []) 

  # convenience functions for archive(user, %Date{} | %Date.Range{}, options)
  def archive(user, :today, options), do: archive(user, Date.utc_today, options)
  def archive(user, :yesterday, options), do: archive(user, Date.utc_today |> Date.add(-1), options)
  def archive(user, :past_week, options), do: archive(user, Date.range(Date.utc_today |> Date.add(-7), Date.utc_today), options)
  def archive(user, :past_month, options), do: archive(user, Date.range(Date.utc_today |> Date.add(-31), Date.utc_today), options)

  # single year archive
  def archive(user, date_range, options) when is_year(date_range) do
    {_, d1} = Date.new(date_range, 1, 1)
    {_, d2} = Date.new(date_range, 12, 31)
    archive(user, Date.range(d1, d2), options)
  end

  # single day/date archive
  def archive(user, date_range = %Date{}, options) do
    IO.puts "Archiving scrobbles for #{user}"
    {from, to} = time_range(date_range)

    {_, new_options} = options |> Keyword.get_and_update(:daily, fn v -> {v, true} end)
    _archive(user, {from, to}, new_options)
    :ok
  end

  # date range archive
  def archive(user, date_range = %Date.Range{}, options) do
    IO.puts "Archiving scrobbles for #{user}"

    daily = option(options, :daily)
    overwrite = option(options, :overwrite)
    interval = option(options, :interval)
    no_scrobble_dates_l = no_scrobble_dates(user)

    if daily do
      for day <- date_range do
        {from, to} = time_range(day)

        file_path = day |> path_from_date
        extracted_day? = File.dir? Path.join(user_data_dir(user), file_path)
        checked_no_scrobble_day? = Enum.member? no_scrobble_dates_l, file_path

        if (not(extracted_day?) and not(checked_no_scrobble_day?)) or overwrite do
           _archive(user, {from, to}, options)
          :timer.sleep(interval)
        end
      end
    else
      # archive data in year batches granularity
      {from, to} = time_range(date_range.first, date_range.last)

      batches = time_range(from, to)
      cond do
        length(batches) == 1 ->
          _archive(user, {from, to}, options)
          :timer.sleep(interval)
        true ->
          {_, t1} = batches |> hd
          {t2, _} = batches |> List.last

          batches = [{from, t1} | (batches |> tl)]
          batches = List.replace_at(batches, -1, {t2, to})
          for {from, to} <- batches do
            _archive(user, {from, to}, options)

            IO.puts ""
            :timer.sleep(interval)
          end
      end
    end
    :ok
  end

  def archive(user, :all, options) do
    {playcount, registered} = info(user)

    IO.puts "Archiving #{playcount} scrobbles for #{user}"

    now = DateTime.utc_now
    last_year_d = Date.from_erl!({now.year - 1, 12, 31})
    from_d = registered |> DateTime.from_unix! |> DateTime.to_date

    # archive data between registration date - end of last year at yearly batches
    archive(user, Date.range(from_d, last_year_d), options)

    # Lastfm API paging chunks from the latest tracks, any new scrobbles would swifts tracks
    # among fixed-size pages -> all downloaded pages for the entire year would need to be updated
    #
    # extracting data in daily timeframes would ensure data immutability/integrity of downloaded pages,
    # enabling easier/fastest/real-time archive syncing and new scrobbles updating
    #
    # archive data in daily batches for this year
    {_, new_year_d} = Date.new(now.year, 1, 1)
    {_, new_options} = options |> Keyword.get_and_update(:daily, fn v -> {v, true} end)

    archive(user, Date.range(new_year_d, Date.utc_today), new_options)
    :ok
  end

  defp _archive(user, date_range_unix, options)

  # daily / year  batch archiving
  defp _archive(user, {from, to}, options) do
    playcount = info(user, {from, to}) |> String.to_integer
    per_page = option(options, :per_page)
    total_pages = (playcount / per_page) |> :math.ceil |> round

    # archive at daily granularity? default is false / yearly basis
    daily = option(options, :daily)

    unless playcount == 0 do
      from_s = from |> date_string_from_unix
      to_s = to |> date_string_from_unix
      to_s = if (to - from) < 86400, do: "", else: "- #{to_s}"

      IO.puts "\n#{from_s}#{to_s}"
      IO.puts "#{playcount} scrobble(s)"
      IO.puts "#{total_pages} page(s)"

      for page <- 1..total_pages, total_pages > 0 do
        # starting from the last page - earliest scrobbles
        fetch_page = total_pages - (page - 1)
        _archive(user, {from, to, fetch_page}, options)
      end
    end

    if daily and playcount == 0 do
      dt = from |> DateTime.from_unix!
      file_path =  dt |> path_from_datetime
      log_no_scrobble(user, file_path)
    end
  end

  defp _archive(user, {from, to, page}, options) do
    dt = from |> DateTime.from_unix!
    interval = option(options, :interval)
    per_page = option(options, :per_page)
    overwrite = option(options, :overwrite)
    daily = option(options, :daily)

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
  def time_range(year) when is_binary(year) do
    {_, dt1, _} = "#{year}-01-01T00:00:00Z" |> DateTime.from_iso8601
    {_, dt2, _} = "#{year}-12-31T23:59:59Z" |> DateTime.from_iso8601
    {dt1 |> DateTime.to_unix, dt2 |> DateTime.to_unix}
  end

  # provide a day range tuple in Unix time for a single date
  @doc false
  def time_range(date = %Date{}) do
    day_s = date |> Date.to_string
    {_, dt1, _} = "#{day_s}T00:00:00Z" |> DateTime.from_iso8601
    {_, dt2, _} = "#{day_s}T23:59:59Z" |> DateTime.from_iso8601
    {dt1 |> DateTime.to_unix, dt2 |> DateTime.to_unix}
  end

  # provide a date range tuple in Unix time between two dates
  @doc false
  def time_range(d1 = %Date{}, d2 = %Date{}) do
    d1_s = d1 |> Date.to_string
    d2_s = d2 |> Date.to_string
    {_, dt1, _} = "#{d1_s}T00:00:00Z" |> DateTime.from_iso8601
    {_, dt2, _} = "#{d2_s}T23:59:59Z" |> DateTime.from_iso8601
    {dt1 |> DateTime.to_unix, dt2 |> DateTime.to_unix}
  end

  # provides a list of year range (first day, last day) tuples in Unix time
  # starting from the user registration date - last year
  @doc false
  def time_range(t1, t2) when is_integer(t1) and is_integer(t2) do
    d1 = DateTime.from_unix!(t1)
    y1 = d1.year

    d2 = DateTime.from_unix!(t2)
    y2 = d2.year
    for year <- y1..y2, do: time_range(year |> to_string)
  end

  defp date_string_from_unix(dt), do: dt |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string

  defp path_from_datetime(dt = %DateTime{}), do: dt |> DateTime.to_date |> Date.to_string |> String.split("-") |> Path.join

  defp path_from_date(d = %Date{}), do: d |> Date.to_string |> String.split("-") |> Path.join

  defp user_data_dir(user), do: (Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir) |> Path.join(user)

  # the option provided through keyword list, config or system default
  defp option(options, key) when is_list(options) and is_atom(key) do
    option = Keyword.get(options, key)
    if option, do: option, else: Application.get_env(:lastfm_archive, key) || @default_opts[key |> to_string]
  end

  defp no_scrobble_dates(user) do
    no_scrobble_log_path =  Path.join [user_data_dir(user), @no_scrobble_log_filenmae]
    unless (File.exists? no_scrobble_log_path) do
      file_dir = Path.dirname no_scrobble_log_path
      unless File.exists?(file_dir), do: File.mkdir_p file_dir
      File.write!(no_scrobble_log_path, "no_scrobble")
    end
    File.read!(no_scrobble_log_path) |> String.split(",")
  end

  defp log_no_scrobble(user, file_path) do
    no_scrobble_log_path =  Path.join [user_data_dir(user), @no_scrobble_log_filenmae]
    no_scrobble_log = File.read!(no_scrobble_log_path)
    unless String.match?(no_scrobble_log, ~r/#{file_path}/) do
      File.write!(no_scrobble_log_path, ",#{file_path}", [:append])
    end
  end


end
