defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.
  """

  @behaviour LastfmArchive.Behaviour.Transformer

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Behaviour.Archive

  import LastfmArchive.Utils, only: [create_dir: 2, month_range: 2, year_range: 1, user_dir: 1, write: 4]
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

  # to update: do not create DF is TSV file already exists
  defp transform(%Metadata{creator: user} = metadata, [%Date{year: year} | _] = months) do
    :ok =
      create_dataframe(metadata, months)
      |> write(year, Path.join([user_dir(user), "tsv", "#{year}.tsv.gz"]), format: :tsv)
  end

  defp create_dataframe(metadata, months) do
    for month <- months do
      {:ok, df} = Archive.impl().read(metadata, month: month)
      df
    end
    |> Explorer.DataFrame.concat_rows()
  end
end
