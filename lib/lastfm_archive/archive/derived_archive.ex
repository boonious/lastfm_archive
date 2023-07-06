defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """

  use LastfmArchive.Behaviour.Archive

  alias LastfmArchive.Utils
  alias Explorer.DataFrame

  @data_frame_io Application.compile_env(:lastfm_archive, :data_frame_io, DataFrame)
  @format_mimetypes %{tsv: "text/tab-separated-values", parquet: "application/vnd.apache.parquet"}

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
      {:ok, Jason.decode!(metadata, keys: :atoms!) |> Metadata.new()}
    end
  end

  defp maybe_create_metadata({:ok, file_archive_metadata}, options) do
    {:ok, Metadata.new(file_archive_metadata, options)}
  end

  # return empty data frame for now
  @impl true
  @spec read(Archive.metadata(), read_options()) :: {:ok, Explorer.DataFrame.t()}
  # def read(metadata, _options), do: {:ok, Explorer.DataFrame.new([], lazy: true)}
  def read(%{creator: user, format: mimetype} = _metadata, year: year), do: {:ok, do_read(user, mimetype, year)}
  def read(_metadata, _options), do: {:error, :einval}

  defp do_read(user, mimetype, year) do
    format = format(mimetype)
    {func_format, opts} = if format == :tsv, do: {:csv, [delimiter: "\t"]}, else: {format, []}

    format
    |> then(fn format -> Utils.read(user, "#{format}/#{year}.#{format}.gz") end)
    |> load_data_frame({func_format, opts})
  end

  defp format(mimetype) do
    format_mimetypes()
    |> Enum.find(fn {_format, type} -> type == mimetype end)
    |> elem(0)
  end

  defp load_data_frame({:ok, data}, {format, opts}), do: apply(@data_frame_io, :"load_#{format}!", [data, opts])

  def format_mimetypes, do: @format_mimetypes
end
