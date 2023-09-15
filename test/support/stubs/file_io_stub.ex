defmodule LastfmArchive.FileIOStub do
  @moduledoc false
  @behaviour LastfmArchive.Behaviour.FileIO

  def read(_path), do: {:ok, ""}
  def read!(_path), do: ""
  def ls!(_path), do: []
  def mkdir_p(_path), do: :ok
  def exists?(_path), do: false
  def write(_path, _data), do: :ok
  def write(_path, _data, _options), do: :ok
end
