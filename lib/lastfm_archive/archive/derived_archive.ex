defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """

  use LastfmArchive.Behaviour.Archive
  use LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings
  alias LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings

  use LastfmArchive.Behaviour.DataFrameIo, formats: FileArchiveTransformerSettings.available_formats()

  @type read_options :: [year: integer()]

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
      {:ok, Jason.decode!(metadata, keys: :atoms) |> Metadata.new()}
    end
  end

  defp maybe_create_metadata({:ok, file_archive_metadata}, options) do
    {:ok, Metadata.new(file_archive_metadata, options)}
  end

  @impl true
  @spec read(Archive.metadata(), read_options()) :: {:ok, Explorer.DataFrame.t()} | {:error, term()}
  def read(%{creator: user, format: mimetype} = _metadata, options) do
    case Keyword.fetch(options, :year) do
      {:ok, year} -> {:ok, do_read(user, mimetype, year)}
      _error -> {:error, :einval}
    end
  end

  defp do_read(user, mimetype, year) do
    {format, %{read_opts: opts}} = setting(mimetype)

    format
    |> filepath(user, year)
    |> load_data_frame(format, opts)
  end

  defp filepath(format, user, year) when format == :csv, do: "#{format}/#{year}.#{format}.gz" |> filepath(user)
  defp filepath(format, user, year), do: "#{format}/#{year}.#{format}" |> filepath(user)
  defp filepath(path_part, user), do: Path.join(user_dir(user), path_part)
end
