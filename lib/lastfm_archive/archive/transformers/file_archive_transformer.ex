defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.
  """

  use LastfmArchive.Archive.Transformers.Transformer

  alias Explorer.DataFrame
  alias LastfmArchive.Archive.DerivedArchive
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [create_dir: 2, create_filepath: 3, month_range: 2, year_range: 1, write: 2]
  require Logger

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

  @impl true
  def apply(%{creator: user} = metadata, opts) do
    :ok = create_dir(user, format: Keyword.fetch!(opts, :format))

    case Keyword.get(opts, :year) do
      nil ->
        :ok = transform(metadata, year_range(metadata.temporal) |> Enum.to_list(), opts)

      year ->
        :ok = transform(metadata, [year], opts)
    end

    {:ok, %{metadata | modified: DateTime.utc_now()}}
  end

  defp transform(_metadata, [], _opts), do: :ok

  defp transform(metadata, [year | rest], opts) when is_integer(year) do
    transform(metadata, month_range(year, metadata), opts)
    transform(metadata, rest, opts)
  end

  defp transform(%Metadata{creator: user} = metadata, [%Date{year: year} | _] = months, opts) do
    format = Keyword.get(opts, :format)
    overwrite = Keyword.get(opts, :overwrite, false)

    case create_filepath(user, format, "#{format}/#{year}.#{format}") do
      {:ok, filepath} ->
        transform({metadata, year, months, filepath, format})

      {:error, :file_exists, filepath} ->
        maybe_skip_transform({metadata, year, months, filepath, format}, overwrite: overwrite)
    end
  end

  defp transform({metadata, year, months, filepath, format}) do
    Logger.info("\nCreating #{format} file for #{year} scrobbles.")
    :ok = create_dataframe(metadata, months) |> write_data_frame(filepath, format: format)
  end

  defp maybe_skip_transform(args, overwrite: true), do: transform(args)

  defp maybe_skip_transform({_, year, _, _, format}, overwrite: false) do
    Logger.info("\n#{format} file exists, skipping #{year} scrobbles.")
  end

  defp create_dataframe(metadata, months) do
    for month <- months do
      Archive.impl().read(metadata, month: month)
    end
    |> Enum.flat_map(fn
      {:ok, %DataFrame{} = df} -> [df]
      _ -> []
    end)
    |> DataFrame.concat_rows()
    |> DataFrame.rename(name: "track")
  end

  defp write_data_frame(df, filepath, format: format) do
    write(df, write_fun(filepath, format))
  end

  defp write_fun(filepath, format) when format == :csv do
    fn df ->
      df
      |> DataFrame.collect()
      |> dump_data_frame(format, DerivedArchive.write_opts(format))
      |> then(fn data -> @file_io.write(filepath, data, [:compressed]) end)
    end
  end

  defp write_fun(filepath, format) do
    fn df ->
      df
      |> DataFrame.collect()
      |> to_data_frame(filepath, format, DerivedArchive.write_opts(format))
    end
  end
end
