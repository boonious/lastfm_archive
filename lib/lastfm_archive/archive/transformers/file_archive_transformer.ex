defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.
  """

  @behaviour LastfmArchive.Behaviour.Transformer

  alias LastfmArchive.Archive.Metadata
  import LastfmArchive.Utils, only: [create_dir: 2, month_range: 2, year_range: 1, user_dir: 1, write: 4]
  require Logger

  @impl true
  def apply(%{creator: user} = metadata, format: :tsv) do
    :ok = create_dir(user, format: :tsv)
    transform(metadata, year_range(metadata.temporal) |> Enum.to_list())

    # to update metadata re. transformation
    {:ok, metadata}
  end

  defp transform(_metadata, []), do: :ok

  defp transform(metadata, [year | rest]) when is_integer(year) do
    transform(metadata, month_range(year, metadata))
    transform(metadata, rest)
  end

  defp transform(%Metadata{creator: user}, [%Date{year: year} | _] = months) do
    :ok =
      create_dataframe(user, months)
      |> write(year, Path.join([user_dir(user), "tsv", "#{year}.tsv.gz"]), format: :tsv)
  end

  defp create_dataframe(user, months) do
    for month <- months do
      {:ok, df} = LastfmArchive.read(user, month: month)
      df
    end
    |> Explorer.DataFrame.concat_rows()
  end
end
