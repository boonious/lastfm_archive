defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble data archive and analytics.
  
  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  
  - `archive/0`, `archive/2`: download raw Lastfm scrobble data to local filesystem.

  """
  # pending, with stop gap functions for `LastfmArchive.Extract.get_recent_tracks`,
  # `LastfmArchive.Extract.get_info`
  # until Elixirfm pull requests are resolved
  # import Elixirfm.User

  import LastfmArchive.Extract

  @default_data_dir "./lastfm_data/"
  #@default_opts %{interval => 500}
  @per_page Application.get_env(:lastfm_archive, :per_page) || 200 # max fetch allowed by Lastfm

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
      ...
  ```

  See `archive/2` for further details on archive format and file location.
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
  ```

  Older scrobbles are archived on a yearly basis, whereas the latest (current year) scrobbles
  are extracted on a daily basis to ensure data immutability and updatability.

  The data is currently in raw Lastfm `recenttracks` JSON format, chunked into
  200-track (max) `gzip` compressed pages and stored within directories corresponding
  to the years and days when tracks were scrobbled.

  `interval` is the duration (in milliseconds) between successive requests
  sent to Lastfm API.
  It provides a control of the max rate of requests.
  The default (500ms) ensures a safe rate that is
  within Lastfm's term of service  - no more than 5 requests per second.

  The data is written to a main directory,
  e.g. `./lastfm_data/a_lastfm_user/` as configured in
  `config/config.exs`:

  ```
    config :lastfm_archive,
      ...
      data_dir: "./lastfm_data/"
  ```

  **Note**: Lastfm API calls could timed out occasionally. When this happen
  the function will continue archiving and move on to the next data chunk (page).
  It will log the missing page in an `error` directory. Re-run the function
  to download any missing data chunks. The function will skip all existing
  archived pages.

  To create a fresh or refresh part of the archive: delete all or some
  files in the archive and re-run the function.
  """
  @spec archive(binary, integer) :: :ok | {:error, :file.posix}
  def archive(user, interval \\ Application.get_env(:lastfm_archive, :interval) || 500) do
    {playcount, registered} = info(user)

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
      _archive(user, {from, to}, interval)

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

    IO.puts "\nyear: #{this_year_s}"

    no_scrobble_log_path =  Path.join [user_data_dir(user), this_year_s, ".no_scrobble"]
    unless (File.exists? no_scrobble_log_path) do
      file_dir = Path.dirname no_scrobble_log_path
      unless File.exists?(file_dir), do: File.mkdir_p file_dir
      File.write!(no_scrobble_log_path, "no_scrobble")
    end

    no_scrobble_path = File.read!(no_scrobble_log_path) |> String.split(",")

    for day <- this_year_day_range do
      day_s = day |> Date.to_string
      {_, dt1, _} = "#{day_s}T00:00:00Z" |> DateTime.from_iso8601
      {_, dt2, _} = "#{day_s}T23:59:59Z" |> DateTime.from_iso8601

      file_path = day_s |> String.split("-") |> Path.join
      extracted_day? = File.dir? Path.join(user_data_dir(user), file_path)
      checked_no_scrobble_day? = Enum.member? no_scrobble_path, file_path

      unless extracted_day? or checked_no_scrobble_day? do
        daily = true
         _archive(user, {dt1 |> DateTime.to_unix, dt2 |> DateTime.to_unix}, interval, daily)
        :timer.sleep(interval)
      end
    end
    :ok
  end

  defp _archive(user, range, interval, daily \\ false)

  # daily batch archiving
  defp _archive(user, {from, to}, interval, true) do
    playcount = info(user, {from, to}) |> String.to_integer
    total_pages = (playcount / @per_page) |> :math.ceil |> round

    unless playcount == 0 do
      IO.puts "\n#{date_string_from_unix(from)}"
      IO.puts "#{playcount} scrobbles"

      daily = true
      for page <- 1..total_pages do
        # starting from the last page - earliest scrobbles
        fetch_page = total_pages - (page - 1)
        _archive(user, {from, to, fetch_page}, interval, daily)
      end
    else
      dt = from |> DateTime.from_unix!
      file_path =  dt |> path_from_datetime
      year_s = dt.year |> to_string
      no_scrobble_log_path =  Path.join [user_data_dir(user), year_s, ".no_scrobble"]
      File.write!(no_scrobble_log_path, ",#{file_path}", [:append])
    end
  end

  # yearly batch archiving
  defp _archive(user, {from, to}, interval, daily) do
    playcount = info(user, {from, to}) |> String.to_integer
    total_pages = (playcount / @per_page) |> :math.ceil |> round

    IO.puts "#{playcount} scrobbles"
    IO.puts "#{total_pages} pages - #{@per_page} scrobbles each"

    for page <- 1..total_pages do
      # starting from the last page - earliest scrobbles
      fetch_page = total_pages - (page - 1)
      _archive(user, {from, to, fetch_page}, interval, daily)
    end
  end

  defp _archive(user, {from, to, page}, interval, daily) do
    dt = from |> DateTime.from_unix!

    filename = if daily do
      dt
      |> path_from_datetime
      |> Path.join(Enum.join(["#{@per_page}", "_", page |> to_string]))
    else
      year_s = dt.year |> to_string
      year_s |> Path.join(Enum.join(["#{@per_page}", "_", page |> to_string]))
    end

    unless file_exists?(user, filename) do
      data = extract(user, page, @per_page, from, to)
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

  #defp get_opts(opts, key) when is_list(opts) and is_atom(key) do
    #option = Keyword.get(opts, key)
    #if option, do: option, else: Application.get_env(:lastfm_archive, key) || @default_opts(key |> to_string)
  #end

end
