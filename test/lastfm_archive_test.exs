defmodule LastfmArchiveTest do
  use ExUnit.Case

  import Fixtures.Archive
  import Hammox

  alias LastfmArchive.Archive.DerivedArchive
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
      csv_archive_metadata: new_derived_archive_metadata(file_archive_metadata, format: :csv),
      parquet_archive_metadata: new_derived_archive_metadata(file_archive_metadata, format: :parquet)
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

  test "read_parquet/2", %{user: user, parquet_archive_metadata: metadata} do
    options = [year: 2023]

    DerivedArchiveMock
    |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
    |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame()} end)

    assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read_parquet(user, options)
  end

  test "read_csv/2", %{user: user, csv_archive_metadata: metadata} do
    options = [year: 2023]

    DerivedArchiveMock
    |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
    |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame()} end)

    assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read_csv(user, options)
  end

  describe "transform/2" do
    for format <- DerivedArchive.formats() do
      test "scrobbles of a user into #{format} files", %{user: user, file_archive_metadata: file_archive_metadata} do
        format = unquote(format)
        metadata = new_derived_archive_metadata(file_archive_metadata, format: format)

        DerivedArchiveMock
        |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
        |> expect(:after_archive, fn ^metadata, FileArchiveTransformer, [format: ^format] -> {:ok, metadata} end)
        |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

        LastfmArchive.transform(user, format: format)
      end
    end

    test "scrobbles of default user with default (CSV) format", %{csv_archive_metadata: metadata} do
      user = Application.get_env(:lastfm_archive, :user)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:after_archive, fn ^metadata, FileArchiveTransformer, [format: :csv] -> {:ok, metadata} end)
      |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      LastfmArchive.transform()
    end
  end
end
