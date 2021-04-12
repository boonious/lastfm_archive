defmodule Lastfm.FileArchiveStub do
  @behaviour Lastfm.Archive

  def describe(_user, _options), do: {:ok, Lastfm.Archive.new("a_lastfm_user")}
  def update_metadata(_archive, _options), do: {:ok, Lastfm.Archive.new("a_lastfm_user")}
  def write(_archive, _scrobbles, _options), do: :ok
end
