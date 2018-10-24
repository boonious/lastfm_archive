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

  The data is currently in raw Lastfm `recenttracks` JSON format, chunked into
  200-track compressed (`gzip`) pages and stored within directories corresponding
  to the years when tracks were scrobbled.

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
  def archive(user, interval \\ Application.get_env(:lastfm_archive, :req_interval) || 500) do
    {playcount, registered} = info(user)
    batches = data_year_range(registered)

    IO.puts "Archiving #{playcount} scrobbles for #{user}"
    for {from, to} <- batches do
      from_s = from |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string
      to_s = to |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string

      IO.puts "\nyear: #{from_s} - #{to_s}"
      _archive(user, {from, to}, interval)

      IO.puts ""
      :timer.sleep(interval) # prevent request rate limit (max 5 per sec) from being reached
    end
    :ok
  end

  defp _archive(user, {from, to}, interval) do
    playcount = info(user, {from, to}) |> String.to_integer
    total_pages = playcount / @per_page |> :math.ceil |> round

    IO.puts "#{playcount} total scrobbles \n#{total_pages} pages - #{@per_page} scrobbles each"
    for page <- 1..total_pages do
      # starting from the last page - earliest scrobbles
      fetch_page = total_pages - (page - 1)
      _archive(user, {from, to}, fetch_page, interval)
    end
  end

  defp _archive(user, {from, to}, page, interval) do
    d0 = from |> DateTime.from_unix!
    year_s = d0.year |> to_string
    filename = year_s |> Path.join(Enum.join(["#{@per_page}", "_", page |> to_string]))

    unless file_exists?(user, filename) do
      data = extract(user, page, @per_page, from, to)
      write(user, data, filename)
      IO.write "."
      :timer.sleep(interval)
    end
  end

  defp file_exists?(user, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    File.exists? file_path
  end

  # provide a year range in Unix time for a particular year
  @doc false
  def data_year_range(year) when is_binary(year) do
    {_, d0, _} = "#{year}-01-01T00:00:00Z" |> DateTime.from_iso8601
    {_, d1, _} = "#{year}-12-31T23:59:59Z" |> DateTime.from_iso8601
    {d0 |> DateTime.to_unix, d1 |> DateTime.to_unix}
  end

  # provides a list of year ranges in Unix time, starting from the user registration date
  @doc false
  def data_year_range(registered, now \\ DateTime.utc_now) when is_integer(registered) do
    d0 = DateTime.from_unix!(registered)
    y0 = d0.year

    this_year = now.year
    for year <- y0..this_year, do: data_year_range(year |> to_string)
  end

end
