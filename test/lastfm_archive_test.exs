defmodule LastfmArchiveTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Hammox

  alias LastfmArchive.Archive.DerivedArchive
  alias LastfmArchive.Archive.DerivedArchiveMock
  alias LastfmArchive.Archive.FileArchiveMock

  setup :verify_on_exit!

  setup_all do
    user = "a_lastfm_user"

    file_archive_metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2023-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      )

    %{user: user, file_archive_metadata: file_archive_metadata}
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

    for format <- DerivedArchive.formats(), facet <- DerivedArchive.facets() do
      test "#{format} derived #{facet} archive", %{user: user, file_archive_metadata: metadata} do
        facet = unquote(facet)
        format = unquote(format)
        metadata = new_derived_archive_metadata(metadata, format: format, facet: facet)
        options = [format: format, year: 2023]

        DerivedArchiveMock
        |> expect(:describe, fn ^user, ^options -> {:ok, metadata} end)
        |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame()} end)

        assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read(user, options)
      end

      test "#{facet} #{format} archive with columns option", %{user: user, file_archive_metadata: metadata} do
        facet = unquote(facet)
        format = unquote(format)
        metadata = new_derived_archive_metadata(metadata, format: format, facet: facet)

        columns = [:artist, :album]
        options = [format: format, year: 2023, columns: columns]

        DerivedArchiveMock
        |> expect(:describe, fn ^user, ^options -> {:ok, metadata} end)
        |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame()} end)

        assert {:ok, %Explorer.DataFrame{}} = LastfmArchive.read(user, options)
      end
    end
  end

  describe "transform/2" do
    for format <- DerivedArchive.formats(), facet <- DerivedArchive.facets() do
      test "#{facet} into #{format} files", %{user: user, file_archive_metadata: file_archive_metadata} do
        facet = unquote(facet)
        format = unquote(format)
        metadata = new_derived_archive_metadata(file_archive_metadata, format: format, facet: facet)

        DerivedArchiveMock
        |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
        |> expect(:after_archive, fn ^metadata, [format: ^format, facet: ^facet] ->
          {:ok, metadata}
        end)
        |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

        LastfmArchive.transform(user, format: format, facet: facet)
      end
    end

    test "scrobbles of default user with default (Arrow IPC stream) format", %{file_archive_metadata: metadata} do
      metadata = new_derived_archive_metadata(metadata, format: :ipc_stream, facet: :scrobbles)
      user = Application.get_env(:lastfm_archive, :user)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
      |> expect(:after_archive, fn ^metadata, [format: :ipc_stream, facet: :scrobbles] ->
        {:ok, metadata}
      end)
      |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      LastfmArchive.transform()
    end
  end
end
