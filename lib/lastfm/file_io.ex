defmodule Lastfm.FileIO do
  @callback read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  @callback mkdir_p(Path.t()) :: :ok | {:error, File.posix()}
  @callback write(Path.t(), iodata()) :: :ok | {:error, File.posix()}
end
