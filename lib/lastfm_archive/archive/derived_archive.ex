defmodule LastfmArchive.Archive.DerivedArchive do
  @moduledoc """
  An archive derived from local data extracted from Lastfm.
  """

  use LastfmArchive.Behaviour.Archive

  @impl true
  def after_archive(metadata, transformer, options), do: transformer.apply(metadata, options)

  # return empty data frame for now
  @impl true
  def read(_metadata, _options), do: {:ok, Explorer.DataFrame.new([], lazy: true)}
end
