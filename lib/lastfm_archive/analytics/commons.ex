defmodule LastfmArchive.Analytics.Commons do
  @moduledoc """
  Common data frame analytics functions.
  """

  alias Explorer.DataFrame
  require Explorer.DataFrame

  @doc """
  Returns a data frame containing most played stats (artists, album etc.) of a data frame.
  """
  @spec most_played(DataFrame.t(), list(String.t()), integer()) :: DataFrame.t()
  def most_played(data_frame, fields, rows \\ 5) do
    data_frame
    |> DataFrame.to_lazy()
    |> DataFrame.group_by(fields)
    |> DataFrame.summarise(playcount: count(name))
    |> DataFrame.arrange(desc: playcount)
    |> DataFrame.head(rows)
  end
end
