defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """
  use LastfmArchive.Behaviour.Archive

  alias Explorer.DataFrame
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Transformers.Transformer

  import LastfmArchive.Utils.Archive, only: [derived_archive_dir: 1, metadata_filepath: 2, user_dir: 2]
  import LastfmArchive.Utils.DateTime, only: [year_range: 1]

  require Explorer.DataFrame

  @type read_options :: [year: integer(), columns: list(atom()), format: atom(), facet: atom()]

  @impl true
  def post_archive(metadata, transformer, options) do
    transformer |> Transformer.apply(metadata, options)
  end

  @impl true
  def describe(user, options) do
    {:ok, metadata} = super(user, [])

    # Fix this: use Utils.File read
    metadata_filepath(user, options)
    |> @file_io.read()
    |> case do
      {:ok, data} -> update_derived_archive_metadata(data |> Jason.decode!(keys: :atoms) |> Metadata.new(), metadata)
      {:error, :enoent} -> metadata |> create_derived_archive_metadata(options)
    end
  end

  defp update_derived_archive_metadata(derived_archive_metadata, file_archive_metadata) do
    {:ok, derived_archive_metadata |> Metadata.new(file_archive_metadata.extent, file_archive_metadata.temporal)}
  end

  defp create_derived_archive_metadata(file_archive_metadata, options) do
    {:ok, Metadata.new(file_archive_metadata, options)}
  end

  @impl true
  @spec read(Archive.metadata(), read_options()) :: {:ok, DataFrame.t()} | {:error, term()}
  def read(%Metadata{creator: user, format: mimetype, type: facet} = metadata, options) do
    with {format, %{read_opts: config_opts}} <- Transformer.format_config(mimetype),
         {:ok, years} <- fetch_years(metadata, Keyword.get(options, :year)),
         {:ok, read_opts} <- fetch_read_opts(config_opts, Keyword.get(options, :columns)) do
      years
      |> make_lazy_dataframe(user, facet, format, read_opts)
      |> merge_facet_stats(facet)
    end
  end

  defp fetch_read_opts(config_opts, nil), do: {:ok, config_opts}
  defp fetch_read_opts(config_opts, columns), do: {:ok, Keyword.put(config_opts, :columns, columns)}

  defp fetch_years(%Metadata{} = metadata, nil), do: {:ok, year_range(metadata.temporal) |> Enum.to_list()}
  defp fetch_years(%Metadata{} = _metadata, year), do: {:ok, [year]}

  defp make_lazy_dataframe(years, user, facet, format, opts) do
    for year <- years do
      archive_dir(facet, format)
      |> filepath(format, user_dir(user, opts), year)
      |> make_lazy_dataframe(format, opts)
    end
    |> DataFrame.concat_rows()
  end

  defp make_lazy_dataframe(filepath, format, opts) do
    apply(Transformer, :"from_#{format}!", [filepath, opts])
    |> DataFrame.to_lazy()
  end

  defp archive_dir(facet, format) do
    [format: format, facet: facet] |> Transformer.validate_opts() |> derived_archive_dir()
  end

  defp filepath(dir, :csv, user_dir, year), do: Path.join(user_dir, "#{dir}/#{year}.csv.gz")
  defp filepath(dir, format, user_dir, year), do: Path.join(user_dir, "#{dir}/#{year}.#{format}")

  defp merge_facet_stats(df, :scrobbles), do: {:ok, df}

  # consolidate yearly stats
  defp merge_facet_stats(df, facet) do
    group = Transformer.facet_transformer_config(facet)[:group] |> List.delete(:year) |> List.delete(:mmdd)

    df
    |> DataFrame.group_by(group)
    |> DataFrame.summarise(first_play: min(first_play), last_play: max(last_play), counts: sum(counts))
    |> then(fn df -> {:ok, df} end)
  end
end
