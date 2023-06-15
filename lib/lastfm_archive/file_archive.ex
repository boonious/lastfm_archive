defmodule LastfmArchive.FileArchive do
  @moduledoc false

  use LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient

  import LastfmArchive.Utils
  require Logger

  @cache Application.compile_env(:lastfm_archive, :cache, LastfmArchive.Cache)

  @impl true
  def archive(metadata, options, client \\ LastfmArchive.LastfmClient.new("user.getrecenttracks"))

  def archive(%{extent: 0} = metadata, _options, _client), do: {:ok, metadata}

  def archive(%{identifier: user} = metadata, options, client) do
    @cache.load(user, @cache, options)

    with {:ok, metadata} <- update_metadata(metadata, options, client) do
      Logger.info("Archiving #{metadata.extent} scrobbles for #{metadata.creator}")
      options = Keyword.validate!(options, default_opts())

      for year <- year_range(metadata.temporal) do
        {from, to} = build_time_range(year, metadata)
        :ok = write_to_archive(metadata, {from, to, @cache.get({user, year}, @cache)}, client, options)
        @cache.serialise(user, @cache, options)
      end

      %{metadata | modified: DateTime.utc_now()} |> Archive.impl().update_metadata(options)
    end
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

  defp write_to_archive(metadata, {from, to, cache}, client, options) do
    for day_range <- build_time_range({from, to}) do
      with {playcount, previous_results} <- Map.get(cache, day_range, {}),
           true <- previous_results |> Enum.all?(&(&1 == :ok)) do
        Logger.info("Skipping #{date(day_range)}, previously synced: #{playcount} scrobble(s)")
      else
        # new daily archiving or redo previous erroneous archiving
        _ -> write_to_archive(metadata, day_range, client, options)
      end
    end

    :ok
  end

  defp write_to_archive(metadata, {from, _to} = time_range, client, options) do
    :timer.sleep(Keyword.fetch!(options, :interval))
    year = DateTime.from_unix!(from).year

    with {:ok, {playcount, _}} <- client_impl().playcount(metadata.identifier, time_range, client),
         num_pages <- num_pages(playcount, Keyword.fetch!(options, :per_page)) do
      Logger.info("#{date(from)}: #{playcount} scrobble(s), #{num_pages} page(s)")
      results = write_to_archive(metadata, time_range, num_pages, client, options)

      # don't cache results of the always partial sync of today's scrobbles
      unless today?(time_range) do
        @cache.put({metadata.identifier, year}, time_range, {playcount, results}, @cache)
      end
    else
      {:error, reason} ->
        Logger.error("Lastfm API error while archiving #{date(time_range)}: #{reason}")
    end
  end

  defp write_to_archive(_metadata, _time_range, 0, _client, _options), do: [:ok]

  defp write_to_archive(%{identifier: user} = metadata, {from, to}, num_pages, client, options) do
    for page <- num_pages..1, num_pages > 0 do
      :timer.sleep(Keyword.fetch!(options, :interval))
      per_page = Keyword.fetch!(options, :per_page)

      with {:ok, scrobbles} <- client_impl().scrobbles(user, {page - 1, per_page, from, to}, client),
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

  defp update_metadata(%{identifier: user} = archive, options, client) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with {:ok, {total, registered_time}} <- client_impl().info(user, %{client | method: "user.getinfo"}),
         {:ok, {_, last_scrobble_time}} <- client_impl().playcount(user, {registered_time, now}, client) do
      LastfmArchive.Archive.new(archive, total, registered_time, last_scrobble_time)
      |> Archive.impl().update_metadata(options)
    end
  end
end
