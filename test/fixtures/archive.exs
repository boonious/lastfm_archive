defmodule Fixtures.Archive do
  alias Lastfm.{Archive, FileArchive}

  def test_file_archive(user), do: %{Archive.new(user) | type: FileArchive}
  def test_file_archive(user, created_datetime), do: %{Archive.new(user) | type: FileArchive, created: created_datetime}
end
