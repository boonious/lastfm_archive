defmodule Fixtures.Archive do
  alias Lastfm.Archive

  def test_file_archive(user), do: Archive.new(user)
  def test_file_archive(user, created_datetime), do: %{Archive.new(user) | created: created_datetime}
end
