defmodule LastfmArchive.Behaviour.Transformer do
  @moduledoc """
  Transform strategy for applying post archive side affects
  """

  @type data_frame :: Explorer.DataFrame.t()
  @type metadata :: LastfmArchive.Archive.Metadata.t()
  @type options :: keyword()

  @callback apply(metadata, options) :: {:ok, metadata()} | {:error, term()}

  @callback source(metadata(), options()) :: data_frame()
  @callback sink(data_frame(), metadata(), options()) :: {:ok, metadata()} | {:error, term()}
  @callback transform(data_frame()) :: data_frame()

  @optional_callbacks transform: 1, sink: 3, source: 2, apply: 2
end
