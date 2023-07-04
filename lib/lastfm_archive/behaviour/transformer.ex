defmodule LastfmArchive.Behaviour.Transformer do
  @moduledoc """
  Transform strategy for applying post archive side affects
  """

  @type metadata :: LastfmArchive.Archive.Metadata.t()
  @type options :: keyword()

  @callback apply(metadata, options) :: {:ok, metadata()} | {:error, term()}
end
