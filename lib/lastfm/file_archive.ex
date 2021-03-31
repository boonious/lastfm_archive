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
    metadata_file = Keyword.get(options, :data_dir, @data_dir) |> create_path(creator)

    case @file_io.read(metadata_file) do
      {:ok, metadata} ->
        maybe_reset({struct(Archive, Jason.decode!(metadata, keys: :atoms!)), metadata_file}, overwrite?: overwrite?)

      {:error, :enoent} ->
        create({archive, metadata_file})
    end
  end

  def create(_archive, _options), do: {:error, :einval}

  def create({archive, metadata_file}) do
    @file_io.mkdir_p(metadata_file |> Path.dirname())

    case @file_io.write(metadata_file, Jason.encode!(%{archive | type: __MODULE__})) do
      :ok -> {:ok, %{archive | type: __MODULE__}}
      {:error, error} -> {:error, error}
    end
  end

  defp create_path(archive_dir, archive_id), do: Path.join([archive_dir, archive_id, @metadata_file])

  defp maybe_reset({archive, metadata_file}, overwrite?: true) do
    create({%{archive | created: DateTime.utc_now()}, metadata_file})
  end

  defp maybe_reset({_archive, _metadata_file}, overwrite?: false), do: {:error, :already_created}

  @impl true
  def describe(archive_id, options \\ []) do
    metadata_file = Keyword.get(options, :data_dir, @data_dir) |> create_path(archive_id)

    case @file_io.read(metadata_file) do
      {:ok, metadata} ->
        metadata = Jason.decode!(metadata, keys: :atoms!)
        type = String.to_existing_atom(metadata.type)
        {:ok, created, _} = DateTime.from_iso8601(metadata.created)
        {:ok, struct(Archive, %{metadata | type: type, created: created})}

      {:error, error} ->
        {:error, error}
    end
  end
end
