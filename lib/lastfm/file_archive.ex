defmodule Lastfm.FileArchive do
  @behaviour Lastfm.Archive

  alias Lastfm.Archive

  @data_dir Application.get_env(:lastfm_archive, :data_dir, "./archive_data/")
  @overwrite Application.get_env(:lastfm_archive, :overwrite, false)
  @metadata_file ".archive"

  @file_io Application.get_env(:lastfm_archive, :file_io)

  @type archive :: Archive.t()
  @type options :: Archive.options()

  @impl true
  def create(%Archive{creator: creator} = archive, options) when creator != nil and is_binary(creator) do
    overwrite? = Keyword.get(options, :overwrite, @overwrite)
    metadata_path = metadata_path(creator, options)

    case @file_io.read(metadata_path) do
      {:ok, data} ->
        maybe_reset({struct(Archive, Jason.decode!(data, keys: :atoms!)), metadata_path}, overwrite?: overwrite?)

      {:error, :enoent} ->
        create({archive, metadata_path})
    end
  end

  def create(_archive, _options), do: {:error, :einval}

  def create({archive, metadata_path}) do
    @file_io.mkdir_p(metadata_path |> Path.dirname())

    case @file_io.write(metadata_path, Jason.encode!(%{archive | type: __MODULE__})) do
      :ok -> {:ok, %{archive | type: __MODULE__}}
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  def archive_dir(options \\ []), do: Keyword.get(options, :data_dir, @data_dir)

  @doc false
  def metadata_path(archive_id, options), do: Path.join([archive_dir(options), archive_id, @metadata_file])

  defp maybe_reset({archive, metadata_path}, overwrite?: true) do
    create({%{archive | created: DateTime.utc_now()}, metadata_path})
  end

  defp maybe_reset({_archive, _metadata_path}, overwrite?: false), do: {:error, :already_created}

  @impl true
  def describe(archive_id, options \\ []) do
    metadata_path = metadata_path(archive_id, options)

    case @file_io.read(metadata_path) do
      {:ok, data} ->
        metadata = Jason.decode!(data, keys: :atoms!)
        type = String.to_existing_atom(metadata.type)
        {:ok, created, _} = DateTime.from_iso8601(metadata.created)
        {:ok, struct(Archive, %{metadata | type: type, created: created})}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def write(archive, scrobbles, options \\ [])

  def write(%Archive{creator: creator} = archive, scrobbles, options) when is_map(scrobbles) do
    metadata_path = metadata_path(creator, options)
    path = Keyword.get(options, :filepath)

    cond do
      path == nil or path == "" ->
        raise "please provide a valid :filepath option"

      !@file_io.exists?(metadata_path) ->
        raise "attempt to write to a non existing archive"

      true ->
        archive_dir = Path.dirname(metadata_path)
        write_to = Path.join(archive_dir, "#{path}.gz")
        write_to_dir = Path.dirname(write_to)
        unless @file_io.exists?(write_to_dir), do: @file_io.mkdir_p(write_to_dir)

        case @file_io.write(write_to, scrobbles |> Jason.encode!(), [:compressed]) do
          :ok ->
            now = DateTime.utc_now()
            {:ok, %{archive | modified: now, date: now |> DateTime.to_date()}}

          {:error, error} ->
            {:error, error}
        end
    end
  end
end
