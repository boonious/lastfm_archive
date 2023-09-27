defmodule LastfmArchive.Archive.Transformers.FacetsTransformer do
  @moduledoc """
  Transform scrobbles into faceted columnar archive.

  This transformer reads and transforms raw scrobbles data into
  a faceted columnar archive, e.g. unique artists, albums, tracks
  """
  use LastfmArchive.Archive.Transformers.Transformer

  alias Explorer.DataFrame
  require Explorer.DataFrame

  @impl true
  def transform(df, opts) do
    group = facet_transformer_config(Keyword.fetch!(opts, :facet))[:group]

    df
    |> DataFrame.select(group ++ [:datetime])
    |> DataFrame.group_by(group)
    |> DataFrame.summarise(first_play: min(datetime), last_play: max(datetime), counts: count(datetime))
    |> DataFrame.distinct(group ++ [:first_play, :last_play, :counts])
  end
end
