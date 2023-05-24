defmodule LastfmArchive.Behaviour.FileIO do
  @moduledoc false

  @callback read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  @callback read!(Path.t()) :: binary()

  @callback mkdir_p(Path.t()) :: :ok | {:error, File.posix()}
  @callback exists?(Path.t()) :: boolean()

  @callback write(Path.t(), iodata()) :: :ok | {:error, File.posix()}
  @callback write(Path.t(), iodata(), keyword()) :: :ok | {:error, File.posix()}
end
