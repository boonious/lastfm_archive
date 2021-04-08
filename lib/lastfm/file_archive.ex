defmodule Lastfm.FileArchive do
  @behaviour Lastfm.Archive

  alias Lastfm.Archive
  alias LastfmArchive.Utils

  @overwrite Application.get_env(:lastfm_archive, :overwrite, false)
  @file_io Application.get_env(:lastfm_archive, :file_io)

  @type archive :: Archive.t()
  @type options :: Archive.options()

  @impl true
  def create(%Archive{creator: creator} = archive, options) when creator != nil and is_binary(creator) do
    overwrite? = Keyword.get(options, :overwrite, @overwrite)
    metadata = Utils.metadata(creator, options)

    case @file_io.read(metadata) do
      {:ok, data} ->
        maybe_reset({struct(Archive, Jason.decode!(data, keys: :atoms!)), metadata}, overwrite?: overwrite?)

      {:error, :enoent} ->
        create({archive, metadata})
    end
  end

  def create(_archive, _options), do: {:error, :einval}

  def create({archive, metadata}) do
    @file_io.mkdir_p(metadata |> Path.dirname())

    case @file_io.write(metadata, Jason.encode!(archive)) do
      :ok -> {:ok, archive}
      error -> error
    end
  end

  defp maybe_reset({archive, metadata}, overwrite?: true) do
    create({%{archive | created: DateTime.utc_now(), date: nil, modified: nil}, metadata})
  end

  defp maybe_reset({_archive, _metadata}, overwrite?: false), do: {:error, :already_created}

  @impl true
  def describe(archive_id, options \\ []) do
    metadata = Utils.metadata(archive_id, options)

    case @file_io.read(metadata) do
      {:ok, data} ->
        metadata = Jason.decode!(data, keys: :atoms!)
        type = String.to_existing_atom(metadata.type)
        {:ok, created, _} = DateTime.from_iso8601(metadata.created)
        {:ok, struct(Archive, %{metadata | type: type, created: created})}

      {:error, :enoent} ->
        {:error, Archive.new(archive_id)}
    end
  end

  @impl true
  def write(archive, scrobbles, options \\ [])

  def write(%Archive{creator: creator}, scrobbles, options) when is_map(scrobbles) do
    metadata = Utils.metadata(creator, options)
    path = Keyword.get(options, :filepath)

    cond do
      path == nil or path == "" ->
        raise "please provide a valid :filepath option"

      !@file_io.exists?(metadata) ->
        raise "attempt to write to a non existing archive"

      true ->
        archive_dir = Path.dirname(metadata)
        to = Path.join(archive_dir, "#{path}.gz")
        to_dir = Path.dirname(to)
        unless @file_io.exists?(to_dir), do: @file_io.mkdir_p(to_dir)
        @file_io.write(to, scrobbles |> Jason.encode!(), [:compressed])
    end
  end
end
