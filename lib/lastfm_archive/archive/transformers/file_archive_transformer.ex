defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformer do
  @moduledoc """
  Transform existing data of file archive into different storage formats.

  This transformer simply reads and converts raw Scrobbles data into
  columnar and other storage formats. It does not apply further data transformation
  or data manipulation.
  """

  use LastfmArchive.Archive.Transformers.Transformer
end
