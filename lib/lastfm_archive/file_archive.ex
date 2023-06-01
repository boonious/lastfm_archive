defmodule LastfmArchive.FileArchive do
  @moduledoc false

  @behaviour LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient

  import LastfmArchive.Utils

  @cache Application.compile_env(:lastfm_archive, :cache, LastfmArchive.Cache)
  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @reset Application.compile_env(:lastfm_archive, :reset, false)

  @impl true
  def update_metadata(%Archive{creator: creator} = metadata, options) when creator != nil and is_binary(creator) do
    write_metadata({metadata, metadata_filepath(creator, options)}, Keyword.get(options, :reset, @reset))
  end

  def update_metadata(_metadata, _options), do: {:error, :einval}

  defp write_metadata({metadata, filepath}, true) do
    write_metadata(%{metadata | created: DateTime.utc_now(), date: nil, modified: nil}, filepath)
  end

  defp write_metadata({metadata, filepath}, false), do: write_metadata(metadata, filepath)

  defp write_metadata(metadata, filepath) do
    filepath |> Path.dirname() |> @file_io.mkdir_p()

    case @file_io.write(filepath, Jason.encode!(metadata)) do
      :ok -> {:ok, metadata}
      error -> error
    end
  end

  @impl true
  def describe(user, options \\ []) do
    metadata_filepath = metadata_filepath(user, options)

    case @file_io.read(metadata_filepath) do
      {:ok, data} ->
        metadata = Jason.decode!(data, keys: :atoms!)

        type = String.to_existing_atom(metadata.type)
        {created, time_range, date} = parse_dates(metadata)

        {:ok, struct(Archive, %{metadata | type: type, created: created, temporal: time_range, date: date})}

      {:error, :enoent} ->
        {:ok, Archive.new(user)}
    end
  end

  defp parse_dates(%{created: created, date: nil, temporal: nil}) do
    {:ok, created, _} = DateTime.from_iso8601(created)
    {created, nil, nil}
  end

  defp parse_dates(%{created: created, date: date, temporal: temporal}) do
    {:ok, created, _} = DateTime.from_iso8601(created)
    [from, to] = temporal
    date = Date.from_iso8601!(date)

    {created, {from, to}, date}
  end

  @impl true
  def archive(metadata, options, client \\ LastfmArchive.LastfmClient.new("user.getrecenttracks"))

  def archive(%{extent: 0} = metadata, _options, _client), do: {:ok, metadata}

  def archive(%{identifier: user} = metadata, options, client) do
    @cache.load(user, @cache, options)

    with {:ok, metadata} <- update_metadata(metadata, options, client) do
      display_progress(metadata)
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
        display_skip_message(day_range, playcount)
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
      display_progress(time_range, playcount, num_pages)
      results = write_to_archive(metadata, time_range, num_pages, client, options)

      # don't cache results of the always partial sync of today's scrobbles
      unless today?(time_range) do
        @cache.put({metadata.identifier, year}, time_range, {playcount, results}, @cache)
      end
    else
      {:error, reason} -> display_api_error_message(time_range, reason)
    end
  end

  defp write_to_archive(_metadata, _time_range, 0, _client, _options), do: [:ok]

  defp write_to_archive(%{identifier: user} = metadata, {from, to}, num_pages, client, options) do
    for page <- num_pages..1, num_pages > 0 do
      :timer.sleep(Keyword.fetch!(options, :interval))
      per_page = Keyword.fetch!(options, :per_page)

      with {:ok, scrobbles} <- client_impl().scrobbles(user, {page - 1, per_page, from, to}, client),
           :ok <- write(metadata, scrobbles, filepath: page_path(from, page, per_page)) do
        IO.write(".")
        :ok
      else
        {:error, _reason} ->
          IO.write("x")
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
      Archive.new(archive, total, registered_time, last_scrobble_time)
      |> Archive.impl().update_metadata(options)
    end
  end
end
