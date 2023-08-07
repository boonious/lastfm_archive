defmodule LastfmArchive.Analytics.Commons do
  @moduledoc """
  Common data frame analytics functions.
  """

  alias Explorer.DataFrame
  require Explorer.DataFrame

  def mutate_pivot_rows(df, field, mutate_fun, pivot_fun) do
    df
    |> DataFrame.group_by(field)
    |> mutate_fun.()
    |> pivot_fun.()
    |> DataFrame.ungroup(field)
  end
end
