defmodule LastfmArchive do
  @moduledoc """
  Documentation for LastfmArchive.
  """

  import Elixirfm.User

  @default_data_dir "./lastfm_data/"
  @req_interval Application.get_env(:lastfm_archive, :req_interval)

  def archive(user, interval \\ @req_interval) when is_binary(user) do
    {_playcount, registered} = info(user)
    batches = data_year_range(registered)

    IO.puts "Archiving Lastfm scrobble data for #{user}"
    for {from, to} <- batches do
      from_s = from |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string
      to_s = to |> DateTime.from_unix! |> DateTime.to_date |> Date.to_string

      IO.puts "\nArchiving year: #{from_s} - #{to_s}"
      :timer.sleep(interval) # prevent request rate limit (max 5 per sec) from being reached
    end
    :ok
  end

  @doc """
  """
  @spec extract :: Elixirfm.response
  def extract, do: extract(Application.get_env(:lastfm_archive, :user))

  @doc """
  """
  @spec extract(binary, integer, integer, integer, integer) :: Elixirfm.response
  def extract(user, page \\ 1, limit \\ 1, from \\ 0, to \\ 0)
  def extract(user, page, limit, from, to), do: get_recent_tracks(user, limit: limit, page: page, extended: 1, from: from, to: to)

  @spec write(binary, binary, binary) :: :ok | {:error, :file.posix}
  def write(data, filename \\ "1", type \\ "file")
  def write(data, filename, type) when is_binary(data), do: _write(data, filename, type)

  defp _write(data, filename, "file") do
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
  def info(user) do
    {_status, resp} = get_info(user)

    playcount = resp["user"]["playcount"]
    registered = resp["user"]["registered"]["unixtime"]

    {playcount, registered}
  end

  # get playcount for a particular year for a user
  def info(user, {from, to}) do
    {_status, resp} = get_recent_tracks(user, limit: 1, page: 1, from: from, to: to)
    resp["recenttracks"]["@attr"]["total"]
  end

  # provide a year range in Unix time for a particular year
  def data_year_range(year) when is_binary(year) do
    {_, d0, _} = "#{year}-01-01T00:00:00Z" |> DateTime.from_iso8601
    {_, d1, _} = "#{year}-12-31T23:59:59Z" |> DateTime.from_iso8601
    {d0 |> DateTime.to_unix, d1 |> DateTime.to_unix}
  end

  # provides a list of year ranges in Unix time, starting from the user registration date
  def data_year_range(registered, now \\ DateTime.utc_now) when is_integer(registered) do
    d0 = DateTime.from_unix!(registered)
    y0 = d0.year

    this_year = now.year
    for year <- y0..this_year, do: data_year_range(year |> to_string)
  end

end
