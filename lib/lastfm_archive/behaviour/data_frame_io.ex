defmodule LastfmArchive.Behaviour.DataFrameIo do
  @moduledoc """
  For Explorer.DataFrame I/O mocks.
  """

  @callback dump_csv!(df :: Explorer.DataFrame.t(), opts :: Keyword.t()) :: String.t()
  @callback dump_parquet!(df :: Explorer.DataFrame.t(), opts :: Keyword.t()) :: binary()

  @callback load_csv!(contents :: String.t(), opts :: Keyword.t()) :: Explorer.DataFrame.t()
  @callback load_parquet!(contents :: binary(), opts :: Keyword.t()) :: Explorer.DataFrame.t()
end
