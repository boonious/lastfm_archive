defmodule LastfmArchive.Behaviour.Transformer do
  @moduledoc """
  Transform strategy for applying post archive side affects
  """

  @type data_frame :: Explorer.DataFrame.t()
  @type metadata :: LastfmArchive.Archive.Metadata.t()
  @type options :: keyword()

  @callback source(metadata(), options()) :: data_frame()
  @callback transform(data_frame(), options()) :: data_frame()
  @callback sink(data_frame(), metadata(), options()) :: :ok
end
