defmodule LastfmArchive.FileArchive do
  @moduledoc false

  @behaviour LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Utils

  @reset Application.compile_env(:lastfm_archive, :reset, false)
  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

  @type archive :: Archive.t()
  @type options :: Archive.options()

  @impl true
  def update_metadata(%Archive{creator: creator} = metadata, options) when creator != nil and is_binary(creator) do
    maybe_reset({metadata, Utils.metadata_filepath(creator, options)}, reset?: Keyword.get(options, :reset, @reset))
  end

  def update_metadata(_archive, _options), do: {:error, :einval}

  defp write_metadata({archive, metadata}) do
    metadata
    |> Path.dirname()
    |> @file_io.mkdir_p()

    case @file_io.write(metadata, Jason.encode!(archive)) do
      :ok -> {:ok, archive}
      error -> error
    end
  end

  defp maybe_reset({archive, metadata}, reset?: true) do
    write_metadata({%{archive | created: DateTime.utc_now(), date: nil, modified: nil}, metadata})
  end

  defp maybe_reset({archive, metadata}, reset?: false), do: write_metadata({archive, metadata})

  @impl true
  def describe(user, options \\ []) do
    metadata_filepath = Utils.metadata_filepath(user, options)

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
  def write(archive, scrobbles, options \\ [])

  def write(%Archive{creator: creator}, scrobbles, options) when is_map(scrobbles) do
    metadata_filepath = Utils.metadata_filepath(creator, options)
    path = Keyword.get(options, :filepath)

    cond do
      path == nil or path == "" ->
        raise "please provide a valid :filepath option"

      !@file_io.exists?(metadata_filepath) ->
        raise "attempt to write to a non existing archive"

      true ->
        archive_dir = Path.dirname(metadata_filepath)
        to = Path.join(archive_dir, "#{path}.gz")
        to_dir = Path.dirname(to)
        unless @file_io.exists?(to_dir), do: @file_io.mkdir_p(to_dir)
        @file_io.write(to, scrobbles |> Jason.encode!(), [:compressed])
    end
  end

  def write(_archive, {:error, api_message}, _options), do: {:error, api_message}
end
