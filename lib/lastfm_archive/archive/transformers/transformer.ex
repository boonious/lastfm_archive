defmodule LastfmArchive.Archive.Transformers.Transformer do
  @moduledoc """
  Base transformer with default implementations.
  """

  use LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings

  use LastfmArchive.Behaviour.DataFrameIo,
    formats: LastfmArchive.Archive.Transformers.FileArchiveTransformerSettings.available_formats()

  require Explorer.DataFrame
  alias Explorer.DataFrame
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [create_filepath: 3, month_range: 2, write: 2]
  require Logger

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @overwrite false

  defmacro __using__(_opts) do
    quote do
      @behaviour LastfmArchive.Behaviour.Transformer
      import LastfmArchive.Archive.Transformers.Transformer
      import LastfmArchive.Utils, only: [create_dir: 2, year_range: 1]

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
        :ok = create_dir(metadata.creator, format: Keyword.fetch!(opts, :format))

        opts
        |> Keyword.get(:year, year_range(metadata.temporal) |> Enum.to_list())
        |> List.wrap()
        |> Enum.each(&data_frame_sink(df, metadata.creator, &1, opts))

        :ok
      end

      # default implementation simply returns data frame without transformation
      @impl true
      def transform(df), do: df

      def apply(metadata, opts) do
        :ok = source(metadata, opts) |> transform() |> sink(metadata, opts)

        {:ok, %{metadata | modified: DateTime.utc_now()}}
      end

      defoverridable source: 2, sink: 3, transform: 1
    end
  end

  def data_frame_source(metadata, year) do
    Logger.info("\nSourcing scrobbles from #{year} into a lazy data frame.")

    for month <- month_range(year, metadata) do
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
    Logger.info("\nSinking data from #{year} into a file.")
    format = Keyword.fetch!(opts, :format)

    df = df |> DataFrame.filter(year == ^year)

    case create_filepath(user, format, "#{format}/#{year}.#{format}") do
      {:ok, filepath} ->
        write(df, write_fun(filepath, format))

      {:error, :file_exists, filepath} ->
        maybe_skip_write({df, filepath, format}, overwrite: Keyword.get(opts, :overwrite, @overwrite))
    end
  end

  defp maybe_skip_write({df, filepath, format}, overwrite: true), do: write(df, write_fun(filepath, format))

  defp maybe_skip_write({_, filepath, _}, overwrite: false) do
    Logger.info("\n#{filepath} exists, skipping writes (overwrite: false)")
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
