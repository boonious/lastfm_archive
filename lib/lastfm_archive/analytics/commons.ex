defmodule LastfmArchive.Analytics.Commons do
  @moduledoc """
  Common data frame analytics functions.
  """

  alias Explorer.DataFrame
  require Explorer.DataFrame

  @doc """
  Returns a lazy data frame containing most played stats (artists, album etc.) for a data frame.
  """
  @spec most_played(DataFrame.t(), list(String.t())) :: DataFrame.t()
  def most_played(data_frame, fields) do
    data_frame
    |> DataFrame.to_lazy()
    |> DataFrame.group_by(fields)
    |> DataFrame.summarise(playcount: count(id))
    |> DataFrame.arrange(desc: playcount)
  end
end
