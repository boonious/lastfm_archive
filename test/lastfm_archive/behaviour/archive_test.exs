defmodule LastfmArchive.TestArchive do
  use LastfmArchive.Behaviour.Archive

  def archive(metadata, _options, _api), do: {:ok, metadata}
  def read(_metadata, _options), do: {:ok, %{}}
end

# tests for default functions in the Archive behaviour
defmodule LastfmArchive.Behaviour.ArchiveTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Hammox
  import LastfmArchive.Utils, only: [metadata_filepath: 2]

  alias LastfmArchive.Archive.Metadata

  setup :verify_on_exit!

  setup do
    %{
      archive: LastfmArchive.TestArchive,
      metadata: file_archive_metadata("a_user"),
      metadata_path: "test_data_dir/a_user/.metadata/file_archive",
      type: :scrobbles
    }
  end

  describe "update_metadata/2" do
    test "writes metadata to file", %{archive: archive, metadata: metadata, metadata_path: path, type: type} do
      metadata_encoded = Jason.encode!(metadata)
      dir = path |> Path.dirname()

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^path, ^metadata_encoded -> :ok end)

      assert {
               :ok,
               %Metadata{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: ^type
               }
             } = archive.update_metadata(metadata, data_dir: "test_data_dir")
    end

    test "reset an existing archive via 'reset' option", %{archive: archive} do
      earlier_created_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      metadata = file_archive_metadata("a_user", earlier_created_datetime)

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn _dir -> :ok end)
      |> expect(:write, fn _path, _ -> :ok end)

      assert {
               :ok,
               %Metadata{
                 created: created,
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 modified: nil,
                 date: nil
               }
             } = archive.update_metadata(metadata, data_dir: "existing_archive", reset: true)

      assert DateTime.compare(earlier_created_datetime, created) == :lt
    end
  end

  describe "describe/2" do
    setup context do
      %{metadata_path: metadata_filepath(context.metadata.creator, [])}
    end

    test "an existing file archive", %{archive: archive, metadata: metadata, metadata_path: path, type: type} do
      user = metadata.creator
      LastfmArchive.FileIOMock |> expect(:read, fn ^path -> {:ok, metadata |> Jason.encode!()} end)

      assert {
               :ok,
               %Metadata{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: ^type,
                 extent: 400,
                 date: %{__struct__: Date},
                 temporal: {1_617_303_007, 1_617_475_807},
                 modified: "2023-06-09T14:36:16.952540Z"
               }
             } = archive.describe(user)
    end

    test "returns new metadata for non-existing archive", %{archive: archive, type: type} do
      LastfmArchive.FileIOMock |> expect(:read, fn _ -> {:error, :enoent} end)

      assert {
               :ok,
               %Metadata{
                 created: %{__struct__: DateTime},
                 creator: "new_user",
                 description: "Lastfm archive of new_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "new_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of new_user",
                 type: ^type,
                 date: nil,
                 extent: nil,
                 modified: nil,
                 temporal: nil
               }
             } = archive.describe("new_user")
    end
  end
end
