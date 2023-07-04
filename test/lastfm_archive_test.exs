defmodule LastfmArchiveTest do
  use ExUnit.Case

  import Fixtures.Archive
  import Hammox

  alias LastfmArchive.Archive.DerivedArchiveMock
  alias LastfmArchive.Archive.FileArchiveMock
  alias LastfmArchive.Archive.Transformers.FileArchiveTransformer

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    user = "a_lastfm_user"

    file_archive_metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2023-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: LastfmArchive.Archive.FileArchive
      )

    %{
      user: user,
      file_archive_metadata: file_archive_metadata,
      tsv_archive_metadata: new_derived_archive_metadata(file_archive_metadata, format: :tsv)
    }
  end

  describe "sync/2" do
    test "scrobbles for the default user to a new file archive", %{file_archive_metadata: metadata} do
      user = Application.get_env(:lastfm_archive, :user)

      FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

      LastfmArchive.sync()
    end

    test "scrobbles of a user to a new file archive", %{user: user, file_archive_metadata: metadata} do
      FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

      LastfmArchive.sync(user)
    end
  end

  describe "read/2" do
    test "scrobbles of a user from a file archive", %{user: user, file_archive_metadata: metadata} do
      date = ~D[2023-06-01]
      option = [day: date]

      FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^option -> {:ok, data_frame()} end)

      assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read(user, option)
    end
  end

  describe "transform/2" do
    test "scrobbles of a user into TSV files", %{user: user, tsv_archive_metadata: metadata} do
      DerivedArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:update_metadata, 2, fn metadata, _options -> {:ok, metadata} end)
      |> expect(:after_archive, fn ^metadata, FileArchiveTransformer, [format: :tsv] -> {:ok, metadata} end)

      LastfmArchive.transform(user, format: :tsv)
    end

    test "scrobbles of default user with default (TSV) format", %{tsv_archive_metadata: metadata} do
      user = Application.get_env(:lastfm_archive, :user)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:update_metadata, 2, fn metadata, _options -> {:ok, metadata} end)
      |> expect(:after_archive, fn ^metadata, FileArchiveTransformer, [format: :tsv] -> {:ok, metadata} end)

      LastfmArchive.transform()
    end
  end
end
