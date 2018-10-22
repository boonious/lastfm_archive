defmodule LastfmArchive do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble data archive and analytics.
  
  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  
  - `archive/2`: download raw Lastfm scrobble data to local filesystem.

  """
  # pending, with stop gap functions for `get_recent_tracks`, `get_info`
  # until Elixirfm pull requests are resolved
  # import Elixirfm.User

  @type lastfm_response :: {:ok, map} | {:error, binary, HTTPoison.Error.t}

  @default_data_dir "./lastfm_data/"
  @per_page Application.get_env(:lastfm_archive, :per_page) || 200 # max fetch allowed by Lastfm
  @req_interval Application.get_env(:lastfm_archive, :req_interval) || 500

  @doc """
  Download all scrobbled tracks and create an archive on local filesystem for a user.

  The data is currently in raw Lastfm `recenttracks` JSON format, chunked into
  200-track compressed (`gzip`) pages and stored within directories corresponding
  to the years when tracks were scrobbled.

  `interval` is the duration (in milliseconds) between successive requests
  sent to Lastfm API.
  It provides a control for the max rate of requests.
  The default (500ms) ensures a safe rate that is
  within Lastfm's term of service  - no more than 5 requests per second.

  The data is written to a main directory,
  e.g. `./lastfm_data/lastfm_username/` as configured below - see
  `config/config.exs`:

  ```
    config :lastfm_archive,
      user: "lastfm_username",
      data_dir: "./lastfm_data/"
  ```

  ### Example

  ```
    LastfmArchive.archive("lastfm_username")
  ```

  **Note**: Lastfm API calls can timed out occasionally. When this happen
  the function will continue archiving and move on to the next data chunk (page).
  It will log the missing page in an `error` directory. Re-run the function
  to download any missing data chunks. The function will skip all existing
  archived pages.

  To create a fresh or refresh part of the archive: delete all or some
  files in the archive and re-run the function.
  """
  @spec archive(binary, integer) :: :ok | {:error, :file.posix}
  def archive(user, interval \\ @req_interval) when is_binary(user) do
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

    unless file_exists?(filename) do
      extract(user, page, @per_page, from, to) |> write(filename)
      IO.write "."
      :timer.sleep(interval)
    end
  end

  defp file_exists?(filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user = Application.get_env(:lastfm_archive, :user) || ""
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    File.exists? file_path
  end

  @doc """
  Issues a request to Lastfm to extract scrobbled tracks for a user.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for details on the use of parameters.
  """
  @spec extract(binary, integer, integer, integer, integer) :: lastfm_response
  def extract(user, page \\ 1, limit \\ 1, from \\ 0, to \\ 0)

  # pending until Elixirfm dependency pull requests are resolved
  #def extract(user, page, limit, from, to), do: get_recent_tracks(user, limit: limit, page: page, extended: 1, from: from, to: to)
  
  # below are stop gap functions for Lastfm API requests until the Elixirfm pull requests
  # are resolved. This is to enable `lastfm_archive` publication on hex
  def extract(user, page, limit, from, to), do: get_tracks(user, limit: limit, page: page, extended: 1, from: from, to: to)
  def get_tracks(user, args \\ []) do
    ext_query_string = encode(args) |> Enum.join
    base_url = Application.get_env(:elixirfm, :lastfm_ws) || "http://ws.audioscrobbler.com/"
    lastfm_key = Application.get_env(:elixirfm, :api_key, System.get_env("LASTFM_API_KEY")) || raise "API key error"

    req_url = "#{base_url}2.0/?method=user.getrecenttracks&user=#{user}#{ext_query_string}&api_key=#{lastfm_key}&format=json"
    HTTPoison.get(req_url, [], [{"Authorization", "Bearer #{lastfm_key}"}])
  end
  defp encode(nil), do: ""
  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for {k, v} <- args, do: encode({k, v})
  # --- end temporary function

  @doc """
  Write binary data or Lastfm response to a configured directory on local filesystem.

  The data is compressed, encoded and stored in a file of given `filename`
  within the user data directory, e.g. `./lastfm_data/a_user/` as configured
  below:

  ```
  config :lastfm_archive,
    user: "a_user",
    data_dir: "./lastfm_data/"
  ```
  """
  @spec write(binary | lastfm_response, binary) :: :ok | {:error, :file.posix}
  def write(data, filename \\ "1")
  
  # stop gap implementation until until Elixirfm pull requests are resolved 
  def write({:ok, %HTTPoison.Response{body: data, headers: _, request_url: _, status_code: _}}, filename), do: write(data, filename)
  def write({:error, %HTTPoison.Error{id: nil, reason: reason}}, filename) do
    write("error", Path.join(["error", reason|>to_string, filename]))
  end

  # pending until Elixirfm pull requests are resolved
  #def write({:ok, data}, filename), do: write(data |> Poison.encode!, filename)
  #def write({:error, _message, %HTTPoison.Error{id: nil, reason: reason}}, filename) do
    #write("error", Path.join(["error", reason|>to_string, filename]))
  #end

  def write(data, filename) when is_binary(data), do: _write(data, filename)

  defp _write(data, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user = Application.get_env(:lastfm_archive, :user) || ""
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    unless File.exists?(user_data_dir), do: File.mkdir_p user_data_dir

    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    file_dir = Path.dirname file_path
    unless File.exists?(file_dir), do: File.mkdir_p file_dir

    File.write file_path, data, [:compressed]
  end

  # find out more about the user (playcount, earliest scrobbles)
  # to determine data extraction strategy
  @doc false
  def info(user) do
    {_status, resp} = get_info(user)

    playcount = resp["user"]["playcount"]
    registered = resp["user"]["registered"]["unixtime"]

    {playcount, registered}
  end

  defp get_info(user) do
    base_url = Application.get_env(:elixirfm, :lastfm_ws) || "http://ws.audioscrobbler.com/"
    lastfm_key = Application.get_env(:elixirfm, :api_key, System.get_env("LASTFM_API_KEY")) || raise "API key error"

    req_url = "#{base_url}2.0/?method=user.getinfo&user=#{user}&api_key=#{lastfm_key}&format=json"
    {status, resp} = HTTPoison.get(req_url, [], [{"Authorization", "Bearer #{lastfm_key}"}])
    {status, resp.body |> Poison.decode!}
  end

  # get playcount for a particular year for a user
  @doc false
  def info(user, {from, to}) do
    # pending, with a stop gap until Elixirfm pull requests are sorted out
    # this is so that `lastfm_archive` can be published on Hex now
    #{_status, resp} = get_recent_tracks(user, limit: 1, page: 1, from: from, to: to)
    #resp["recenttracks"]["@attr"]["total"]
    
    # stop gap
    {_status, resp} = get_tracks(user, limit: 1, page: 1, from: from, to: to)
    resp_body = resp.body |> Poison.decode!
    resp_body["recenttracks"]["@attr"]["total"]
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
