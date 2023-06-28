defmodule LastfmArchive.Behaviour.DataFrameIo do
  @moduledoc """
  For Explorer.DataFrame I/O mocks.
  """

  @callback to_csv(df :: Explorer.DataFrame.t(), filename :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
end
