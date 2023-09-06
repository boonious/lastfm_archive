defmodule LastfmArchive.Archive.Transformers.Transformer do
  @moduledoc """
  Base transformer with default implementations.
  """

  use LastfmArchive.Archive.Transformers.TransformerSettings
  use LastfmArchive.Behaviour.DataFrameIo, formats: LastfmArchive.Archive.Transformers.TransformerSettings.formats()

  alias Explorer.DataFrame
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [maybe_create_dir: 2, check_filepath: 2, write: 2, user_dir: 2]
  import LastfmArchive.Utils.DateTime, only: [month_range: 2, year_range: 1]

  require Explorer.DataFrame
  require Logger

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

  defmacro __using__(_opts) do
    quote do
      @behaviour LastfmArchive.Behaviour.Transformer
      import LastfmArchive.Archive.Transformers.Transformer
      import LastfmArchive.Utils.DateTime, only: [year_range: 1]

      @impl true
      def source(metadata, opts) do
        opts
        |> Keyword.get(:year, year_range(metadata.temporal) |> Enum.to_list())
        |> List.wrap()
        |> Enum.map(&data_frame_source(metadata, &1))
        |> DataFrame.concat_rows()
      end

      @impl true
      def sink(df, metadata, opts) do
        opts
        |> Keyword.get(:year, year_range(metadata.temporal) |> Enum.to_list())
        |> List.wrap()
        |> Enum.each(&data_frame_sink(df, metadata.creator, &1, opts))

        :ok
      end

      # default implementation simply returns data frame without transformation
      @impl true
      def transform(df, _opts), do: df

      defoverridable source: 2, sink: 3, transform: 2
    end
  end

  def apply(transformer, metadata, opts) do
    maybe_create_archive_dir(metadata.creator, opts)
    run_pipeline(transformer, metadata, opts, Keyword.get(opts, :year, year_range(metadata.temporal) |> Enum.to_list()))
    {:ok, %{metadata | modified: DateTime.utc_now()}}
  end

  defp run_pipeline(transformer, metadata, opts, year) when is_integer(year) do
    run_pipeline(transformer, metadata, opts)
  end

  defp run_pipeline(transformer, metadata, opts, years) when is_list(years) do
    for year <- years do
      opts
      |> Keyword.merge(year: year)
      |> then(fn opts -> run_pipeline(transformer, metadata, opts) end)
    end
  end

  defp run_pipeline(transformer, metadata, opts) do
    transformer.source(metadata, opts) |> transformer.transform(opts) |> transformer.sink(metadata, opts)
  end

  defp maybe_create_archive_dir(user, opts) do
    opts
    |> validate_opts()
    |> then(fn opts -> maybe_create_dir(user_dir(user, opts), sub_dir: derived_archive_dir(opts)) end)
  end

  def data_frame_source(metadata, year) do
    Logger.info("\nSourcing scrobbles from #{year} into a lazy data frame.")

    for month <- month_range(year, metadata.temporal) do
      Archive.impl().read(metadata, month: month)
    end
    |> Enum.flat_map(fn
      {:ok, %DataFrame{} = df} -> [df]
      _ -> []
    end)
    |> DataFrame.concat_rows()
    |> DataFrame.rename(name: "track")
  end

  def data_frame_sink(df, user, year, opts) do
    Logger.info("\nWriting data from #{year}")
    opts = opts |> validate_opts()
    format = Keyword.fetch!(opts, :format)
    filepath = Path.join([user_dir(user, opts), "#{derived_archive_dir(opts)}/#{year}.#{format}"])
    df = df |> DataFrame.filter(year == ^year)

    case check_filepath(format, filepath) do
      {:ok, filepath} ->
        write(df, write_fun(filepath, format))

      {:error, :file_exists, filepath} ->
        maybe_skip_write({df, filepath, format}, overwrite: Keyword.fetch!(opts, :overwrite))
    end
  end

  defp maybe_skip_write({df, filepath, format}, overwrite: true), do: write(df, write_fun(filepath, format))

  defp maybe_skip_write({_, filepath, _}, overwrite: false) do
    Logger.info("\nSkipping writes (overwrite: false), #{filepath} exists")
  end

  defp write_fun(filepath, :csv) do
    fn df ->
      df
      |> DataFrame.collect()
      |> dump_data_frame(:csv, write_opts(:csv))
      |> then(fn data -> @file_io.write(filepath, data, [:compressed]) end)
    end
  end

  defp write_fun(filepath, format) do
    fn df ->
      df
      |> DataFrame.collect()
      |> to_data_frame(filepath, format, write_opts(format))
    end
  end
end
