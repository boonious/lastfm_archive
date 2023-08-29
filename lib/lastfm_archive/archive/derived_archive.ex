defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """
  use LastfmArchive.Behaviour.Archive
  use LastfmArchive.Archive.Transformers.TransformerSettings

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Transformers.Transformer
  alias LastfmArchive.Archive.Transformers.TransformerSettings

  use LastfmArchive.Behaviour.DataFrameIo, formats: TransformerSettings.formats()

  @type read_options :: [year: integer(), columns: list(atom()), format: atom(), facet: atom()]

  @impl true
  def after_archive(metadata, options) do
    transformer(Keyword.fetch!(options, :facet)) |> Transformer.apply(metadata, options)
  end

  @impl true
  def describe(user, options) do
    {:ok, metadata} = super(user, [])

    metadata_filepath(user, options)
    |> @file_io.read()
    |> case do
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
  def read(%Metadata{creator: user, format: mimetype, type: facet} = metadata, options) do
    with {format, %{read_opts: config_opts}} <- setting(mimetype),
         {:ok, years} <- fetch_years(metadata, Keyword.get(options, :year)),
         {:ok, read_opts} <- fetch_read_opts(config_opts, Keyword.get(options, :columns)) do
      years
      |> create_lazy_dataframe(user, facet, format, read_opts)
      |> then(fn df -> {:ok, df} end)
    end
  end

  defp fetch_read_opts(config_opts, nil), do: {:ok, config_opts}
  defp fetch_read_opts(config_opts, columns), do: {:ok, Keyword.put(config_opts, :columns, columns)}

  defp fetch_years(%Metadata{} = metadata, nil), do: {:ok, year_range(metadata.temporal) |> Enum.to_list()}
  defp fetch_years(%Metadata{} = _metadata, year), do: {:ok, [year]}

  defp filepath(dir, :csv, user, year), do: Path.join(user_dir(user), "#{dir}/#{year}.csv.gz")
  defp filepath(dir, format, user, year), do: Path.join(user_dir(user), "#{dir}/#{year}.#{format}")

  defp create_lazy_dataframe(years, user, facet, format, opts) do
    for year <- years do
      filepath(derived_archive_dir(format: format, facet: facet), format, user, year)
      |> load_data_frame(format, opts)
      |> Explorer.DataFrame.to_lazy()
    end
    |> Explorer.DataFrame.concat_rows()
  end
end
