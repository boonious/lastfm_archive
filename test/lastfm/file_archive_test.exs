defmodule Lastfm.FileArchiveTest do
  use ExUnit.Case, async: true

  import Mox
  import Fixtures.{Archive, Lastfm}

  alias Lastfm.{Archive, FileArchive}

  @archive Application.get_env(:lastfm_archive, :type)

  setup :verify_on_exit!

  describe "create/2" do
    test "new empty file archive, writes and returns metadata" do
      new_archive = test_file_archive("a_user")
      archive_metadata = Jason.encode!(new_archive)

      Lastfm.FileIOMock
      |> expect(:read, fn "new_archive/a_user/.archive" -> {:error, :enoent} end)
      |> expect(:mkdir_p, fn "new_archive/a_user" -> :ok end)
      |> expect(:write, fn "new_archive/a_user/.archive", ^archive_metadata -> :ok end)

      assert {
               :ok,
               %Archive{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: @archive
               }
             } = FileArchive.create(new_archive, data_dir: "new_archive")
    end

    test "does not create new file archive if one already exists" do
      existing_archive = test_file_archive("a_user")

      Lastfm.FileIOMock
      |> expect(:read, fn "existing_archive/a_user/.archive" -> {:ok, "{\"creator\": \"lastfm_user\"}"} end)
      |> expect(:mkdir_p, 0, fn "existing_archive/a_user" -> :ok end)
      |> expect(:write, 0, fn "existing_archive/a_user/.archive", _ -> :ok end)

      assert {:error, :already_created} == FileArchive.create(existing_archive, data_dir: "existing_archive")
    end

    test "reset an existing archive with 'overwrite' option" do
      earlier_created_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      existing_archive = test_file_archive("a_user", earlier_created_datetime)
      archive_metadata = Jason.encode!(existing_archive)

      Lastfm.FileIOMock
      |> expect(:read, fn "existing_archive/a_user/.archive" -> {:ok, archive_metadata} end)
      |> expect(:mkdir_p, fn "existing_archive/a_user" -> :ok end)
      |> expect(:write, fn "existing_archive/a_user/.archive", _ -> :ok end)

      assert {
               :ok,
               %Archive{
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
             } = FileArchive.create(existing_archive, data_dir: "existing_archive", overwrite: true)

      assert DateTime.compare(earlier_created_datetime, created) == :lt
    end
  end

  describe "describe/2" do
    test "an existing file archive" do
      archive_id = "a_user"
      metadata_path = Path.join([Application.get_env(:lastfm_archive, :data_dir), archive_id, ".archive"])
      metadata = Jason.encode!(test_file_archive(archive_id))

      Lastfm.FileIOMock |> expect(:read, fn ^metadata_path -> {:ok, metadata} end)

      assert {
               :ok,
               %Archive{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: @archive
               }
             } = FileArchive.describe("a_user")
    end

    test "return error if file archive does not exist" do
      Lastfm.FileIOMock |> expect(:read, fn _ -> {:error, :enoent} end)
      assert {:error, _new_archive_to_created} = FileArchive.describe("non_existig_archive_id")
    end
  end

  describe "write/2" do
    setup do
      archive_id = "a_user"
      scrobbles = recent_tracks(archive_id, 5) |> Jason.decode!()
      scrobbles_json = scrobbles |> Jason.encode!()
      metadata = Path.join([Application.get_env(:lastfm_archive, :data_dir), archive_id, ".archive"])
      full_gzip_path = Path.join(Path.dirname(metadata), "2000/200_1.gz")

      %{
        id: archive_id,
        data: scrobbles,
        data_json: scrobbles_json,
        path: "2000/200_1",
        metadata: metadata,
        full_path: full_gzip_path,
        full_dir: Path.dirname(full_gzip_path)
      }
    end

    test "scrobbles into a file archive",
         context = %{data_json: data_json, metadata: metadata, full_path: full_path, full_dir: full_dir} do
      Lastfm.FileIOMock
      |> expect(:exists?, fn ^metadata -> true end)
      |> expect(:exists?, fn ^full_dir -> false end)
      |> expect(:mkdir_p, fn ^full_dir -> :ok end)
      |> expect(:write, fn ^full_path, ^data_json, [:compressed] -> :ok end)

      assert :ok == FileArchive.write(test_file_archive(context.id), context.data, filepath: context.path)
    end

    test "does not write to non existing archive",
         context = %{id: id, data_json: data_json, metadata: metadata, full_path: full_path} do
      Lastfm.FileIOMock
      |> expect(:exists?, fn ^metadata -> false end)
      |> expect(:write, 0, fn ^full_path, ^data_json, [:compressed] -> true end)

      assert_raise RuntimeError, "attempt to write to a non existing archive", fn ->
        FileArchive.write(test_file_archive(id), context.data, filepath: context.path)
      end
    end

    test "does not write to archive without a filepath option",
         context = %{id: id, data_json: data_json, full_path: full_path} do
      Lastfm.FileIOMock |> expect(:write, 0, fn ^full_path, ^data_json, [:compressed] -> true end)

      assert_raise RuntimeError, "please provide a valid :filepath option", fn ->
        FileArchive.write(test_file_archive(id), context.data)
      end
    end

    test "does not write to archive on empty or nil filepath",
         context = %{id: id, data_json: data_json, full_path: full_path} do
      Lastfm.FileIOMock |> expect(:write, 0, fn ^full_path, ^data_json, [:compressed] -> true end)

      assert_raise RuntimeError, "please provide a valid :filepath option", fn ->
        FileArchive.write(test_file_archive(id), context.data, filepath: nil)
      end

      assert_raise RuntimeError, "please provide a valid :filepath option", fn ->
        FileArchive.write(test_file_archive(id), context.data, filepath: "")
      end
    end
  end
end
