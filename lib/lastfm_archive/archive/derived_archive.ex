defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """

  use LastfmArchive.Behaviour.Archive

  @impl true
  def after_archive(metadata, transformer, options), do: transformer.apply(metadata, options)

  @impl true
  def describe(user, options) do
    case @file_io.read(metadata_filepath(user, options)) do
      {:ok, metadata} -> {:ok, Jason.decode!(metadata, keys: :atoms) |> Metadata.new()}
      {:error, :enoent} -> file_archive_metadata(user) |> maybe_create_metadata(options)
    end
  end

  defp file_archive_metadata(user) do
    with {:ok, metadata} <- @file_io.read(metadata_filepath(user)) do
      {:ok, Jason.decode!(metadata, keys: :atoms!) |> Metadata.new()}
    end
  end

  defp maybe_create_metadata({:ok, file_archive_metadata}, options) do
    {:ok, Metadata.new(file_archive_metadata, options)}
  end

  # return empty data frame for now
  @impl true
  def read(_metadata, _options), do: {:ok, Explorer.DataFrame.new([], lazy: true)}
end
