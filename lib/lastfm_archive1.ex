defmodule LastfmArchive1 do
  @moduledoc """
  `lastfm_archive` is a tool for creating local Last.fm scrobble file archive, Solr archive and analytics.

  The software is currently experimental and in preliminary development. It should
  eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

  Current usage:
  - `sync/0`, `sync/2`: sync Lastfm scrobble data to local filesystem
  """

  alias Lastfm.Archive
  alias LastfmArchive.Utils

  @default_opts %{
    interval: Application.get_env(:lastfm_archive, :interval, 500),
    per_page: Application.get_env(:lastfm_archive, :per_page, 200),
    reset: Application.get_env(:lastfm_archive, :reset, false),
    data_dir: Application.get_env(:lastfm_archive, :data_dir, "./archive_data/")
  }

  @api Application.get_env(:lastfm_archive, :lastfm_client)
  @archive Application.get_env(:lastfm_archive, :type, Lastfm.FileArchive)
  @file_io Application.get_env(:lastfm_archive, :file_io)

  @type archive :: Archive.t()
  @type time_range :: {integer, integer}

  @doc """
  Sync scrobbled tracks for the default user.

  ### Example

  ```
    LastfmArchive.sync
  ```

  The first sync downloads all scrobbles and creates an archive on local filesystem. Subsequent sync calls
  download the latest scrobbles starting from the previous date of sync.

  See `archive/0` for further details on how to configured a default user.
  """
  @spec sync :: :ok | {:error, :file.posix()}
  def sync do
    user = Application.get_env(:lastfm_archive, :user) || raise "User not found in configuration"
    sync(user)
  end

  @doc """
  Sync scrobbled tracks for a Lastfm user.

  ### Example

  ```
    LastfmArchive.sync("a_lastfm_user")
  ```

  The first sync downloads all scrobbles and creates an archive on local filesystem. Subsequent sync calls
  download only the latest scrobbles starting from the previous date of sync. The date of sync is logged in
  a `.lastfm_archive` file in the user archive data directory.

  """
  @spec sync(binary, keyword) :: :ok | {:error, :file.posix()}
  def sync(user, options \\ []), do: @archive.describe(user, options) |> maybe_sync_archive(options)

  defp maybe_sync_archive({:ok, archive}, options), do: sync_archive(archive, options)

  defp maybe_sync_archive({:error, %{identifier: user} = archive}, options) do
    client = %Lastfm.Client{method: "user.getrecenttracks"}
    now = DateTime.utc_now() |> DateTime.to_unix()

    with {total, registered_time} <- @api.info(user, %{client | method: "user.getinfo"}),
         {_, last_scrobble_time} <- @api.playcount(user, {registered_time, now}, client),
         archive <- update_archive(archive, total, {registered_time, last_scrobble_time}),
         {:ok, archive} <- @archive.update_metadata(archive, options) do
      Utils.display_progress(archive)
      metadata = Utils.metadata(user, options)

      for year <- Utils.year_range(archive.temporal) do
        {from, to} = Utils.build_time_range(year)

        sync_results =
          case @file_io.read(Utils.sync_result_cache(year, user, options)) do
            {:ok, cache} -> sync_archive(archive, {from, to, cache |> :erlang.binary_to_term()}, options)
            _ -> sync_archive(archive, {from, to, %{}}, options)
          end

        @file_io.write(Utils.sync_result_cache(year, user, options), sync_results |> :erlang.term_to_binary())
        @file_io.write(metadata, %{archive | modified: DateTime.utc_now()} |> Jason.encode!())
      end

      :ok
    else
      error -> error
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

  @spec sync_archive(archive, keyword) :: map
  def sync_archive(archive, time_range, options \\ [])

  def sync_archive(%Archive{extent: 0}, _year_time_range, _options), do: :ok

  def sync_archive(archive = %Archive{modified: nil}, {from, to, cache}, options) do
    client = %Lastfm.Client{method: "user.getrecenttracks"}
    options = Map.merge(@default_opts, Enum.into(options, @default_opts))

    time_ranges = Utils.build_time_range({from, to})

    for time_range <- time_ranges, within_range?(time_range, archive.temporal), into: %{} do
      case Map.get(cache, time_range) do
        {playcount, sync_results} ->
          IO.puts("\n")
          IO.puts("Skipping, previous playcount #{playcount}")
          {time_range, {playcount, sync_results}}

        _ ->
          :timer.sleep(options.interval)

          {playcount, _} = @api.playcount(archive.identifier, time_range, client)
          pages = (playcount / options.per_page) |> :math.ceil() |> round

          Utils.display_progress(time_range, playcount, pages)
          sync_results = sync_archive(archive, time_range, pages, options)

          {time_range, {playcount, sync_results}}
      end
    end
  end

  defp within_range?({from, to}, {registered_time, last_scrobble_time}) do
    from < last_scrobble_time and to > registered_time
  end

  @spec sync_archive(archive, time_range, integer, map) :: list()
  def sync_archive(_archive, _time_range, 0, _options), do: [:ok]

  def sync_archive(archive = %{identifier: user}, {from, to}, pages, options) do
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
end
