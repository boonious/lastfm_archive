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

  alias LastfmArchive.Archive.Metadata

  @archive Application.compile_env(:lastfm_archive, :type)

  setup :verify_on_exit!

  setup do
    %{archive: LastfmArchive.TestArchive, metadata: file_archive_metadata("a_user")}
  end

  describe "update_metadata/2" do
    test "writes metadata to file", %{archive: archive, metadata: metadata} do
      metadata_encoded = Jason.encode!(metadata)

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn "test_data_dir/a_user" -> :ok end)
      |> expect(:write, fn "test_data_dir/a_user/.file_archive_metadata", ^metadata_encoded -> :ok end)

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
                 type: @archive
               }
             } = archive.update_metadata(metadata, data_dir: "test_data_dir")
    end

    test "reset an existing archive via 'overwrite' option", %{archive: archive} do
      earlier_created_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      metadata = file_archive_metadata("a_user", earlier_created_datetime)

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn "existing_archive/a_user" -> :ok end)
      |> expect(:write, fn "existing_archive/a_user/.file_archive_metadata", _ -> :ok end)

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
    test "an existing file archive", %{archive: archive, metadata: metadata} do
      archive_id = metadata.creator
      metadata_path = Path.join([Application.get_env(:lastfm_archive, :data_dir), archive_id, ".file_archive_metadata"])

      LastfmArchive.FileIOMock |> expect(:read, fn ^metadata_path -> {:ok, metadata |> Jason.encode!()} end)

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
                 type: @archive,
                 extent: 400,
                 date: %{__struct__: Date},
                 temporal: {1_617_303_007, 1_617_475_807},
                 modified: "2023-06-09T14:36:16.952540Z"
               }
             } = archive.describe(archive_id)
    end

    test "returns new metadata for non-existing archive", %{archive: archive} do
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
                 type: @archive,
                 date: nil,
                 extent: nil,
                 modified: nil,
                 temporal: nil
               }
             } = archive.describe("new_user")
    end
  end
end
