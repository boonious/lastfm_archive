defmodule LastfmArchive.FileArchiveTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Fixtures.{Archive, Lastfm}
  import Hammox

  alias LastfmArchive.Archive, as: ArchiveStuct
  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.Behaviour.LastfmClient
  alias LastfmArchive.FileArchive
  alias LastfmArchive.Utils

  @archive Application.compile_env(:lastfm_archive, :type)

  setup :verify_on_exit!

  describe "update_metadata/2" do
    test "of file archive, writes and returns metadata" do
      new_archive = test_file_archive("a_user")
      archive_metadata = Jason.encode!(new_archive)

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn "new_archive/a_user" -> :ok end)
      |> expect(:write, fn "new_archive/a_user/.archive", ^archive_metadata -> :ok end)

      assert {
               :ok,
               %ArchiveStuct{
                 created: %{__struct__: DateTime},
                 creator: "a_user",
                 description: "Lastfm archive of a_user, extracted from Lastfm API",
                 format: "application/json",
                 identifier: "a_user",
                 source: "http://ws.audioscrobbler.com/2.0",
                 title: "Lastfm archive of a_user",
                 type: @archive
               }
             } = FileArchive.update_metadata(new_archive, data_dir: "new_archive")
    end

    test "reset an existing archive with 'overwrite' option" do
      earlier_created_datetime = DateTime.add(DateTime.utc_now(), -3600, :second)
      existing_archive = test_file_archive("a_user", earlier_created_datetime)

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn "existing_archive/a_user" -> :ok end)
      |> expect(:write, fn "existing_archive/a_user/.archive", _ -> :ok end)

      assert {
               :ok,
               %ArchiveStuct{
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
             } = FileArchive.update_metadata(existing_archive, data_dir: "existing_archive", reset: true)

      assert DateTime.compare(earlier_created_datetime, created) == :lt
    end
  end

  describe "describe/2" do
    test "an existing file archive" do
      archive_id = "a_user"
      metadata_path = Path.join([Application.get_env(:lastfm_archive, :data_dir), archive_id, ".archive"])
      metadata = Jason.encode!(test_file_archive(archive_id))

      LastfmArchive.FileIOMock |> expect(:read, fn ^metadata_path -> {:ok, metadata} end)

      assert {
               :ok,
               %ArchiveStuct{
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
      LastfmArchive.FileIOMock |> expect(:read, fn _ -> {:error, :enoent} end)
      assert {:ok, _new_archive_to_created} = FileArchive.describe("non_existig_archive_id")
    end
  end

  describe "archive/3" do
    setup do
      user = "a_lastfm_user"
      scrobbles = recent_tracks(user, 5) |> Jason.decode!()

      total_scrobbles = 400
      registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      last_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

      stub_with(LastfmClient.impl(), LastfmArchive.LastfmClientStub)
      stub_with(LastfmArchive.CacheMock, LastfmArchive.CacheStub)
      stub_with(LastfmArchive.FileIOMock, LastfmArchive.FileIOStub)
      Archive.impl() |> stub(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      metadata = %{
        LastfmArchive.Archive.new("a_lastfm_user")
        | temporal: {registered_time, last_scrobble_time},
          extent: total_scrobbles,
          date: ~D[2021-04-03],
          type: FileArchive
      }

      %{
        metadata: metadata,
        scrobbles: scrobbles,
        scrobbles_json: scrobbles |> Jason.encode!(),
        user: user
      }
    end

    test "calls Lastfm API via the client", %{
      metadata: metadata,
      scrobbles: scrobbles,
      user: user
    } do
      daily_playcount = 13
      {registered_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn ^user, _client -> {:ok, {total_scrobbles, registered_time}} end)
      |> expect(:playcount, fn ^user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {:ok, {daily_playcount, last_scrobble_time}} end)
      |> stub(:scrobbles, fn ^user, _client_args, _client -> {:ok, scrobbles} end)

      Archive.impl()
      |> expect(:update_metadata, fn ^metadata, _options -> {:ok, metadata} end)
      |> expect(:update_metadata, fn metadata, _options -> {:ok, metadata} end)

      capture_log(fn -> assert {:ok, %ArchiveStuct{}} = FileArchive.archive(metadata, []) end)
    end

    test "writes scrobbles to files", %{
      metadata: metadata,
      scrobbles_json: scrobbles_json,
      user: user
    } do
      # write 3 files for 3-day test archive duration
      LastfmArchive.FileIOMock
      |> expect(:exists?, 3, fn _page_dir -> false end)
      |> expect(:mkdir_p, 3, fn _page_dir -> :ok end)
      |> expect(:write, 3, fn full_path, ^scrobbles_json, [:compressed] ->
        assert full_path =~ "./lastfm_data/test/#{user}/2021/04"
        assert full_path =~ "/200_001.gz"
        :ok
      end)

      capture_log(fn -> FileArchive.archive(metadata, []) end)
    end

    test "caches archiving ok status", %{metadata: metadata, user: user} do
      LastfmArchive.CacheMock
      |> expect(:put, 3, fn {^user, 2021}, _time, {_playcount, [:ok]}, _cache -> :ok end)

      capture_log(fn -> FileArchive.archive(metadata, []) end)
    end

    test "caches status on scrobbles API call errors", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:scrobbles, 3, fn _user, _client_args, _client -> {:error, "error"} end)

      LastfmArchive.CacheMock
      |> expect(:put, 3, fn {^user, 2021}, _time, {_playcount, [error: _data]}, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ "Lastfm API error"
    end

    test "does not cache status of today's scrobbles (partial) archiving", %{metadata: metadata, user: user} do
      registered_time = (DateTime.utc_now() |> DateTime.to_unix()) - 100
      last_scrobble_time = DateTime.utc_now() |> DateTime.to_unix()
      total_scrobbles = 2

      metadata = %{
        metadata
        | temporal: {registered_time, last_scrobble_time},
          extent: total_scrobbles,
          date: Date.utc_today()
      }

      Archive.impl() |> stub(:update_metadata, fn _metadata, _options -> {:ok, metadata} end)

      LastfmClient.impl()
      |> expect(:info, fn ^user, _api -> {:ok, {total_scrobbles, registered_time}} end)
      |> expect(:playcount, 2, fn ^user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> expect(:scrobbles, fn ^user, _client_args, _client -> {:ok, %{}} end)

      LastfmArchive.CacheMock
      |> expect(:put, 0, fn {_user, _year}, {_from, _to}, {_total_scrobbles, _status}, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ Date.utc_today() |> to_string
    end

    test "handles first total playcount API call error", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:playcount, fn ^user, _time_range, _client -> {:error, "error"} end)
      assert FileArchive.archive(metadata, []) == {:error, "error"}
    end

    test "handles first user info API call error", %{metadata: metadata, user: user} do
      LastfmClient.impl() |> expect(:info, fn ^user, _client -> {:error, "error"} end)
      assert FileArchive.archive(metadata, []) == {:error, "error"}
    end

    test "handles and does not cache status of time-range playcount API call errors", %{
      metadata: metadata,
      scrobbles: scrobbles,
      user: user
    } do
      api_error = "error"
      {registered_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn ^user, _client -> {:ok, {total_scrobbles, registered_time}} end)
      |> expect(:playcount, fn ^user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {:error, api_error} end)
      |> stub(:scrobbles, fn ^user, _client_args, _client -> {:ok, scrobbles} end)

      LastfmArchive.CacheMock
      |> expect(:put, 0, fn {^user, 2021}, _time, {_playcount, _status}, _cache -> :ok end)

      assert capture_log(fn -> FileArchive.archive(metadata, []) end) =~ "Lastfm API error"
    end

    test "does nothing when user have 0 scrobble", %{metadata: metadata} do
      LastfmClient.impl()
      |> expect(:info, 0, fn _user, _client -> {:ok, ""} end)
      |> expect(:playcount, 0, fn _user, _time_range, _client -> {:ok, ""} end)
      |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)

      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      assert {:ok, %ArchiveStuct{extent: 0}} = FileArchive.archive(%{metadata | extent: 0}, [])
    end

    test "does not write to files and make scrobbles calls on 0 playcount day", %{metadata: metadata} do
      daily_playcount = 0
      {registered_time, last_scrobble_time} = metadata.temporal
      total_scrobbles = metadata.extent

      LastfmClient.impl()
      |> expect(:info, fn _user, _client -> {:ok, {total_scrobbles, registered_time}} end)
      |> expect(:playcount, fn _user, _time_range, _client -> {:ok, {total_scrobbles, last_scrobble_time}} end)
      |> stub(:playcount, fn _user, _time_range, _api -> {:ok, {daily_playcount, last_scrobble_time}} end)
      |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)

      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      capture_log(fn -> assert {:ok, %ArchiveStuct{}} = FileArchive.archive(metadata, []) end)
    end

    test "skip archiving on ok status in cache", %{metadata: metadata, user: user} do
      daily_playcount = 13

      cache_ok_status =
        metadata.temporal
        |> Utils.build_time_range()
        |> Enum.into(%{}, fn time_range -> {time_range, {daily_playcount, [:ok]}} end)

      LastfmArchive.CacheMock |> expect(:get, fn {^user, 2021}, _cache -> cache_ok_status end)

      LastfmClient.impl() |> expect(:scrobbles, 0, fn _user, _client_args, _client -> {:ok, ""} end)
      LastfmArchive.FileIOMock |> expect(:write, 0, fn _path, _data, [:compressed] -> :ok end)

      assert capture_log(fn -> assert {:ok, %ArchiveStuct{}} = FileArchive.archive(metadata, []) end) =~ "Skipping"
    end
  end
end
