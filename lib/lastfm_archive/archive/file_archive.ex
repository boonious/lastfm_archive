defmodule LastfmArchive.Archive.FileArchive do
  @moduledoc false

  use LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Scrobble

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient

  alias LastfmArchive.LastfmClient.LastfmApi

  import LastfmArchive.Utils
  require Logger

  @cache Application.compile_env(:lastfm_archive, :cache, LastfmArchive.Cache)

  @impl true
  def archive(metadata, options, api \\ LastfmApi.new("user.getrecenttracks"))

  def archive(%{extent: 0} = metadata, _options, _api), do: {:ok, metadata}

  def archive(%{identifier: user} = metadata, options, api) do
    @cache.load(user, @cache, options)

    with {:ok, metadata} <- update_metadata(metadata, options, api) do
      Logger.info("Archiving #{metadata.extent} scrobbles for #{metadata.creator}")
      options = Keyword.validate!(options, default_opts())

      for year <- year_range(metadata.temporal) do
        {from, to} = build_time_range(year, metadata)
        :ok = write_to_archive(metadata, {from, to, @cache.get({user, year}, @cache)}, api, options)
        @cache.serialise(user, @cache, options)
      end

      %{metadata | modified: DateTime.utc_now()} |> Archive.impl().update_metadata(options)
    end
  end

  @impl true
  def read(%{creator: user} = _metadata, day: %Date{} = date), do: do_read(user, day: date)
  def read(%{creator: user} = _metadata, month: %Date{} = date), do: do_read(user, month: date)
  def read(_metadata, _options), do: {:error, :einval}

  defp do_read(user, option) do
    for filepath <- ls_archive_files(user, option) do
      create_lazy_data_frame(user, filepath)
    end
    |> Explorer.DataFrame.concat_rows()
  end

  defp create_lazy_data_frame(user, file_path) do
    LastfmArchive.Utils.read(user, file_path)
    |> then(fn {:ok, scrobbles} -> scrobbles |> Jason.decode!() end)
    |> Scrobble.new()
    |> Enum.map(&Map.from_struct/1)
    |> Explorer.DataFrame.new(lazy: true)
  end

  defp client_impl, do: LastfmClient.impl()

  defp default_opts do
    [
      interval: Application.get_env(:lastfm_archive, :interval, 1000),
      per_page: Application.get_env(:lastfm_archive, :per_page, 200),
      reset: Application.get_env(:lastfm_archive, :reset, false),
      data_dir: Application.get_env(:lastfm_archive, :data_dir, "./lastfm_data/")
    ]
  end

  defp write_to_archive(metadata, {from, to, cache}, api, options) do
    for day_range <- build_time_range({from, to}) do
      with {playcount, previous_results} <- Map.get(cache, day_range, {}),
           true <- previous_results |> Enum.all?(&(&1 == :ok)) do
        Logger.info("Skipping #{date(day_range)}, previously synced: #{playcount} scrobble(s)")
      else
        # new daily archiving or redo previous erroneous archiving
        _ -> write_to_archive(metadata, day_range, api, options)
      end
    end

    :ok
  end

  defp write_to_archive(metadata, {from, _to} = time_range, api, options) do
    :timer.sleep(Keyword.fetch!(options, :interval))
    year = DateTime.from_unix!(from).year

    with {:ok, {playcount, _}} <- client_impl().playcount(metadata.identifier, time_range, api),
         num_pages <- num_pages(playcount, Keyword.fetch!(options, :per_page)) do
      Logger.info("#{date(from)}: #{playcount} scrobble(s), #{num_pages} page(s)")
      results = write_to_archive(metadata, time_range, num_pages, api, options)

      # don't cache results of the always partial sync of today's scrobbles
      unless today?(time_range) do
        @cache.put({metadata.identifier, year}, time_range, {playcount, results}, @cache)
      end
    else
      {:error, reason} ->
        Logger.error("Lastfm API error while archiving #{date(time_range)}: #{reason}")
    end
  end

  defp write_to_archive(_metadata, _time_range, 0, _api, _options), do: [:ok]

  defp write_to_archive(%{identifier: user} = metadata, {from, to}, num_pages, api, options) do
    for page <- num_pages..1, num_pages > 0 do
      :timer.sleep(Keyword.fetch!(options, :interval))
      per_page = Keyword.fetch!(options, :per_page)

      with {:ok, scrobbles} <- client_impl().scrobbles(user, {page - 1, per_page, from, to}, api),
           :ok <- write(metadata, scrobbles, filepath: page_path(from, page, per_page)) do
        Logger.info("✓ page #{page} written to #{user_dir(user)}/#{page_path(from, page, per_page)}.gz")
        :ok
      else
        {:error, reason} ->
          Logger.error("❌ Lastfm API error while retrieving scrobbles #{date(from)}: #{reason}")
          {:error, %{user: user, page: page - 1, from: from, to: to, per_page: per_page}}
      end
    end
  end

  defp today?({from, _to}) do
    DateTime.from_unix!(from) |> DateTime.to_date() |> Kernel.==(Date.utc_today())
  end

  defp update_metadata(%{identifier: user} = archive, options, api) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with {:ok, {total, registered_time}} <- client_impl().info(user, %{api | method: "user.getinfo"}),
         {:ok, {_, last_scrobble_time}} <- client_impl().playcount(user, {registered_time, now}, api) do
      Metadata.new(archive, total, registered_time, last_scrobble_time)
      |> Archive.impl().update_metadata(options)
    end
  end
end
