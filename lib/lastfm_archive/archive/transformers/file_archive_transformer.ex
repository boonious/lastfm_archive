defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.
  """

  @behaviour LastfmArchive.Behaviour.Transformer

  alias Explorer.DataFrame
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [create_dir: 2, create_filepath: 2, month_range: 2, year_range: 1, write: 2]
  require Logger

  @data_frame_io Application.compile_env(:lastfm_archive, :data_frame_io, DataFrame)
  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

  @impl true
  def apply(%{creator: user} = metadata, [format: format] = opts) do
    :ok = create_dir(user, format: format)
    :ok = transform(metadata, year_range(metadata.temporal) |> Enum.to_list(), opts)

    {:ok, %{metadata | modified: DateTime.utc_now()}}
  end

  defp transform(_metadata, [], _opts), do: :ok

  defp transform(metadata, [year | rest], opts) when is_integer(year) do
    transform(metadata, month_range(year, metadata), opts)
    transform(metadata, rest, opts)
  end

  defp transform(%Metadata{creator: user} = metadata, [%Date{year: year} | _] = months, opts) do
    format = Keyword.get(opts, :format)

    case create_filepath(user, "#{format}/#{year}.#{format}.gz") do
      {:ok, filepath} ->
        Logger.info("\nCreating #{format} file for #{year} scrobbles.")
        :ok = create_dataframe(metadata, months) |> write_data_frame(filepath, format: format)

      {:error, :file_exists} ->
        Logger.info("\n#{format} file exists, skipping #{year} scrobbles.")
    end
  end

  defp create_dataframe(metadata, months) do
    for month <- months do
      {:ok, df} = Archive.impl().read(metadata, month: month)
      df
    end
    |> DataFrame.concat_rows()
  end

  defp write_data_frame(df, filepath, format: :tsv) do
    write_fun = fn df ->
      df
      |> DataFrame.collect()
      |> @data_frame_io.dump_csv!(delimiter: "\t")
      |> then(fn data -> @file_io.write(filepath, data, [:compressed]) end)
    end

    write(df, write_fun)
  end
end
