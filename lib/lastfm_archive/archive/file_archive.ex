defmodule LastfmArchive.Archive.FileArchive do
  @moduledoc """
  An archive containing raw data extracted from Lastfm API.
  """
  use LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Scrobble

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient

  alias LastfmArchive.Cache
  alias LastfmArchive.Cache.Server, as: CacheServer
  alias LastfmArchive.LastfmClient.LastfmApi

  import LastfmArchive.Utils
  import LastfmArchive.Utils.DateTime, except: [month_range: 2]

  require Logger

  @cache Application.compile_env(:lastfm_archive, :cache, LastfmArchive.Cache)

  @type read_options :: [day: Date.t(), month: Date.t()]

  @impl true
  def archive(metadata, options, api \\ LastfmApi.new("user.getrecenttracks"))
  def archive(%{extent: 0} = metadata, _options, _api), do: {:ok, metadata}

  def archive(%{creator: user} = metadata, options, api) do
    setup(user, options)

    with {:ok, metadata} <- update_metadata(metadata, options, api),
         options <- Keyword.validate!(options, default_opts()),
         {years, date} <- years_and_date(metadata, options) do
      archive(metadata, options, api, years, date)
      %{metadata | modified: DateTime.utc_now()} |> Archive.impl().update_metadata(options)
    end
  end

  defp setup(user, opts) do
    maybe_create_dir(user_dir(user, opts), sub_dir: Cache.cache_dir())

    # migrate previous cache files to .cache dir
    # to be removed in a future version
    maybe_migrate_old_cache_files(user, opts)

    # needs unloading when archiving session is done
    @cache.load(user, CacheServer, opts)
  end

  defp archive(%{creator: user} = metadata, options, api, years, date) when is_nil(date) do
    Logger.info("Archiving #{metadata.extent} scrobbles for #{metadata.creator}")

    for year <- years do
      {from, to} = time_for_year(year, metadata.temporal)
      :ok = write_to_archive(metadata, {from, to, @cache.get({user, year}, CacheServer)}, api, options)
      @cache.serialise(user, CacheServer, options)
    end
  end

  defp archive(%{creator: user} = metadata, options, api, _years, %Date{year: year} = date) do
    Logger.info("Archiving scrobbles on #{date} for #{metadata.creator}")

    {from, to} = iso8601_to_unix("#{date}T00:00:00Z", "#{date}T23:59:59Z")

    case date_in_range?(metadata, {from, to}) do
      true ->
        :ok = write_to_archive(metadata, {from, to, @cache.get({user, year}, CacheServer)}, api, options)
        @cache.serialise(user, CacheServer, options)

      false ->
        raise("date option out of range")
    end
  end

  defp years_and_date(metadata, options) do
    years = year_range(metadata.temporal)

    years =
      case Keyword.fetch!(options, :year) do
        nil -> years
        year -> if year in years, do: [year], else: raise("year option not within range")
      end

    {years, Keyword.fetch!(options, :date)}
  end

  defp maybe_migrate_old_cache_files(user, opts) do
    Path.join(user_dir(user, opts), ".cache_????")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(&rename_file(user, opts, &1))
  end

  defp rename_file(user, opts, old_cache_file) do
    ".cache_" <> year = old_cache_file |> Path.basename()

    new_file = Path.join([user_dir(user, opts), Cache.cache_dir(), year])
    Logger.info("migrate old cache file #{old_cache_file} to #{new_file}")

    File.rename(old_cache_file, new_file)
  end

  @impl true
  @spec read(Archive.metadata(), read_options()) :: {:error, :einval} | {:ok, Explorer.DataFrame.t()}
  def read(%{creator: user} = _metadata, day: %Date{} = date), do: {:ok, do_read(user, day: date)}
  def read(%{creator: user} = _metadata, month: %Date{} = date), do: {:ok, do_read(user, month: date)}
  def read(_metadata, _options), do: {:error, :einval}

  defp do_read(user, opts) do
    for filepath <- ls_archive_files(user, opts) do
      create_lazy_data_frame(Path.join(user_dir(user, opts), filepath))
    end
    |> case do
      [] -> {:error, :einval}
      dfs -> dfs |> Explorer.DataFrame.concat_rows()
    end
  end

  defp create_lazy_data_frame(filepath) do
    LastfmArchive.Utils.read(filepath)
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
      data_dir: Application.get_env(:lastfm_archive, :data_dir, "./lastfm_data/"),
      date: nil,
      year: nil,
      overwrite: false
    ]
  end

  defp write_to_archive(metadata, {from, to, cache}, api, options) do
    for day_range <- daily_time_ranges({from, to}) do
      with {playcount, previous_results} <- Map.get(cache, day_range, {}),
           true <- previous_results |> Enum.all?(&(&1 == :ok)),
           false <- Keyword.fetch!(options, :overwrite) do
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
      unless today?(from) do
        @cache.put({metadata.identifier, year}, time_range, {playcount, results}, options, CacheServer)
      end
    else
      {:error, reason} ->
        Logger.error("Lastfm API error while archiving #{date(time_range)}: #{reason}")
    end
  end

  defp write_to_archive(_metadata, _time_range, 0, _api, _options), do: [:ok]

  defp write_to_archive(%{identifier: user} = metadata, {from, to}, num_pages, api, opts) do
    for page <- num_pages..1, num_pages > 0 do
      :timer.sleep(Keyword.fetch!(opts, :interval))
      per_page = Keyword.fetch!(opts, :per_page)

      with {:ok, scrobbles} <- client_impl().scrobbles(user, {page - 1, per_page, from, to}, api),
           :ok <- write(metadata, scrobbles, filepath: page_path(from, page, per_page)) do
        Logger.info("✓ page #{page} written to #{user_dir(user, opts)}/#{page_path(from, page, per_page)}.gz")
        :ok
      else
        {:error, reason} ->
          Logger.error("❌ Lastfm API error while retrieving scrobbles #{date(from)}: #{reason}")
          {:error, %{user: user, page: page - 1, from: from, to: to, per_page: per_page}}
      end
    end
  end

  defp update_metadata(%{identifier: user} = archive, options, api) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with {:ok, {total, registered_time}} <- client_impl().info(user, %{api | method: "user.getinfo"}),
         {:ok, {_, last_scrobble_time}} <- client_impl().playcount(user, {registered_time, now}, api) do
      Metadata.new(archive, total, {registered_time, last_scrobble_time})
      |> Archive.impl().update_metadata(options)
    end
  end
end
