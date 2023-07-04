defmodule LastfmArchive.Behaviour.DataFrameIo do
  @moduledoc """
  For Explorer.DataFrame I/O mocks.
  """

  @callback dump_csv!(df :: Explorer.DataFrame.t(), opts :: Keyword.t()) :: String.t()
end
