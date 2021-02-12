defmodule Lastfm.FileArchiveTest do
  use ExUnit.Case, async: true

  import Mox
  import Fixtures.Archive

  alias Lastfm.{Archive, FileArchive}

  setup :verify_on_exit!

  describe "create/2" do
    test "new empty file archive, writes and returns metadata" do
      new_archive = test_file_archive("a_user")
      archive_metadata = Jason.encode!(new_archive)

      Lastfm.FileIOMock |> expect(:read, fn "new_archive/a_user/.archive" -> {:error, :enoent} end)
      Lastfm.FileIOMock |> expect(:mkdir_p, fn "new_archive/a_user" -> :ok end)
      Lastfm.FileIOMock |> expect(:write, fn "new_archive/a_user/.archive", ^archive_metadata -> :ok end)

      assert {
               :ok,
               %Archive{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API,",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: FileArchive
               }
             } = FileArchive.create(new_archive, data_dir: "new_archive")
    end

    test "does not create new file archive if one already exists" do
      existing_archive = test_file_archive("a_user")

      Lastfm.FileIOMock
      |> expect(:read, fn "existing_archive/a_user/.archive" -> {:ok, "{\"creator\": \"lastfm_user\"}"} end)

      Lastfm.FileIOMock |> expect(:mkdir_p, 0, fn "existing_archive/a_user" -> :ok end)
      Lastfm.FileIOMock |> expect(:write, 0, fn "existing_archive/a_user/.archive", _ -> :ok end)

      assert {:error, :already_created} == FileArchive.create(existing_archive, data_dir: "existing_archive")
    end

    test "reset an existing archive with 'overwrite' option" do
      earlier_created_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      existing_archive = test_file_archive("a_user", earlier_created_datetime)
      archive_metadata = Jason.encode!(existing_archive)

      Lastfm.FileIOMock |> expect(:read, fn "existing_archive/a_user/.archive" -> {:ok, archive_metadata} end)
      Lastfm.FileIOMock |> expect(:mkdir_p, fn "existing_archive/a_user" -> :ok end)
      Lastfm.FileIOMock |> expect(:write, fn "existing_archive/a_user/.archive", _ -> :ok end)

      assert {
               :ok,
               %Archive{
                 created: created,
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API,",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: FileArchive
               }
             } = FileArchive.create(existing_archive, data_dir: "existing_archive", overwrite: true)

      assert DateTime.compare(earlier_created_datetime, created) == :lt
    end
  end
end
