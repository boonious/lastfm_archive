defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """
  use LastfmArchive.Behaviour.Archive
  use LastfmArchive.Archive.Transformers.TransformerSettings

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Transformers.TransformerSettings

  use LastfmArchive.Behaviour.DataFrameIo, formats: TransformerSettings.formats()

  @type read_options :: [year: integer(), columns: list(atom())]

  @impl true
  def after_archive(metadata, transformer, options), do: transformer.apply(metadata, options)

  @impl true
  def describe(user, options) do
    {:ok, metadata} = super(user, [])

    case @file_io.read(metadata_filepath(user, options)) do
      {:ok, data} -> revise_derived_archive_metadata(data |> Jason.decode!(keys: :atoms) |> Metadata.new(), metadata)
      {:error, :enoent} -> metadata |> create_derived_archive_metadata(options)
    end
  end

  defp revise_derived_archive_metadata(derived_archive_metadata, file_archive_metadata) do
    {:ok, derived_archive_metadata |> Metadata.new(file_archive_metadata.extent, file_archive_metadata.temporal)}
  end

  defp create_derived_archive_metadata(file_archive_metadata, options) do
    {:ok, Metadata.new(file_archive_metadata, options)}
  end

  @impl true
  @spec read(Archive.metadata(), read_options()) :: {:ok, Explorer.DataFrame.t()} | {:error, term()}
  def read(%Metadata{creator: user, format: mimetype} = metadata, options) do
    with {format, %{read_opts: config_opts}} <- setting(mimetype),
         {:ok, {years, read_opts}} <- fetch_opts(metadata, config_opts, options) do
      years
      |> create_lazy_dataframe(user, format, read_opts)
      |> then(fn df -> {:ok, df} end)
    end
  end

  defp fetch_opts(%Metadata{} = metadata, config_opts, options) do
    with {:ok, years} <- fetch_years(metadata, Keyword.get(options, :year)),
         columns <- Keyword.get(options, :columns) do
      fetch_opts(config_opts, years, columns)
    end
  end

  defp fetch_opts(config_opts, years, nil), do: {:ok, {years, config_opts}}
  defp fetch_opts(config_opts, years, columns), do: {:ok, {years, Keyword.put(config_opts, :columns, columns)}}

  defp fetch_years(%Metadata{} = metadata, nil), do: {:ok, year_range(metadata.temporal) |> Enum.to_list()}
  defp fetch_years(%Metadata{} = _metadata, year), do: {:ok, [year]}

  defp filepath(dir, :csv, user, year), do: Path.join(user_dir(user), "#{dir}/#{year}.csv.gz")
  defp filepath(dir, format, user, year), do: Path.join(user_dir(user), "#{dir}/#{year}.#{format}")

  defp create_lazy_dataframe(years, user, format, opts) do
    for year <- years do
      filepath(derived_archive_dir(format: format), format, user, year)
      |> load_data_frame(format, opts)
      |> Explorer.DataFrame.to_lazy()
    end
    |> Explorer.DataFrame.concat_rows()
  end
end
