defmodule LastfmArchiveTest do
  use ExUnit.Case

  import Fixtures.Archive
  import Hammox

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    user = "a_lastfm_user"

    %{
      user: user,
      metadata: new_archive_metadata(user: user, type: LastfmArchive.Archive.FileArchive)
    }
  end

  describe "sync/2" do
    test "scrobbles for the default user to a new file archive", %{metadata: metadata} do
      user = Application.get_env(:lastfm_archive, :user)

      LastfmArchive.Archive.FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

      LastfmArchive.sync()
    end

    test "scrobbles of a user to a new file archive", %{user: user, metadata: metadata} do
      LastfmArchive.Archive.FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

      LastfmArchive.sync(user)
    end
  end

  describe "read/2" do
    test "scrobbles of a user from a file archive", %{user: user, metadata: metadata} do
      date = ~D[2023-06-01]
      option = [day: date]

      LastfmArchive.Archive.FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^option -> {:ok, data_frame()} end)

      assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read(user, option)
    end
  end
end
