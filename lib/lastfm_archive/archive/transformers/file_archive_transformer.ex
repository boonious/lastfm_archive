defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.
  """

  @behaviour LastfmArchive.Behaviour.Transformer

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [create_dir: 2, create_filepath: 2, month_range: 2, year_range: 1, write: 3]
  require Logger

  @impl true
  def apply(%{creator: user} = metadata, format: :tsv) do
    :ok = create_dir(user, format: :tsv)
    :ok = transform(metadata, year_range(metadata.temporal) |> Enum.to_list())

    {:ok, %{metadata | modified: DateTime.utc_now()}}
  end

  defp transform(_metadata, []), do: :ok

  defp transform(metadata, [year | rest]) when is_integer(year) do
    transform(metadata, month_range(year, metadata))
    transform(metadata, rest)
  end

  defp transform(%Metadata{creator: user} = metadata, [%Date{year: year} | _] = months) do
    case create_filepath(user, "tsv/#{year}.tsv.gz") do
      {:ok, filepath} ->
        Logger.info("\nCreating TSV file for #{year} scrobbles.")
        :ok = create_dataframe(metadata, months) |> write(filepath, format: :tsv)

      {:error, :file_exists} ->
        Logger.info("\nTSV file exists, skipping #{year} scrobbles.")
    end
  end

  defp create_dataframe(metadata, months) do
    for month <- months do
      {:ok, df} = Archive.impl().read(metadata, month: month)
      df
    end
    |> Explorer.DataFrame.concat_rows()
  end
end
