defmodule LastfmArchive.Archive.Transformers.FacetTransformer do
  @moduledoc """
  Transform scrobbles into faceted columnar archive.

  This transformer reads and transforms raw scrobbles data into
  a faceted columnar archive, e.g. unique artists, albums, tracks
  """

  use LastfmArchive.Archive.Transformers.Transformer

  # placeholder transform
  @impl true
  def transform(df), do: df
end
