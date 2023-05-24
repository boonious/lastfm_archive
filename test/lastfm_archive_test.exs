defmodule LastfmArchiveTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mox
  import Fixtures.Archive

  alias LastfmArchive.Behaviour.Archive
  alias LastfmArchive.FileArchive
  alias LastfmArchive.LastfmClientMock

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    stub_with(LastfmClientMock, LastfmArchive.LastfmClientStub)
    stub_with(LastfmArchive.FileArchiveMock, LastfmArchive.FileArchiveStub)
    stub_with(LastfmArchive.CacheMock, LastfmArchive.CacheStub)

    total_scrobbles = 400
    registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    last_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

    test_archive = %{
      Archive.new("a_lastfm_user")
      | temporal: {registered_time, last_scrobble_time},
        extent: total_scrobbles,
        date: ~D[2021-04-03],
        type: FileArchive
    }

    %{user: "a_lastfm_user", archive: test_archive}
  end

  test "sync scrobbles to a new file archive" do
    user = Application.get_env(:lastfm_archive, :user)
    LastfmArchive.FileArchiveMock |> expect(:describe, fn ^user, _options -> {:ok, test_file_archive()} end)
    capture_io(fn -> LastfmArchive.sync(user) end)
  end

  test "sync/2 scrobbles to a new file archive", %{user: user, archive: archive} do
    daily_playcount = 13
    {registered_time, last_scrobble_time} = archive.temporal
    total_scrobbles = archive.extent

    LastfmArchive.FileArchiveMock
    |> expect(:describe, fn ^user, _options -> {:ok, archive} end)
    |> expect(:update_metadata, fn ^archive, _options -> {:ok, archive} end)
    |> stub(:update_metadata, fn _updated_archive, _options -> {:ok, archive} end)

    LastfmClientMock
    |> expect(:info, fn ^user, _api -> {:ok, {total_scrobbles, registered_time}} end)
    |> expect(:playcount, fn ^user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
    |> stub(:playcount, fn ^user, _time_range, _api -> {:ok, {daily_playcount, 0}} end)

    capture_io(fn -> LastfmArchive.sync(user) end)
  end

  test "sync/2 handles initial user info API call error", %{user: user} do
    LastfmClientMock
    |> stub(:info, fn ^user, _api -> {:error, "Last.fm API: something went wrong"} end)
    |> expect(:playcount, 0, fn ^user, _time_range, _api -> {:ok, {0, 0}} end)

    assert {:error, "Last.fm API: something went wrong"} == LastfmArchive.sync(user)
  end

  test "sync/2 handles initial total playcount API call error", %{user: user} do
    LastfmClientMock
    |> expect(:info, 1, fn ^user, _api -> {:ok, {0, 0}} end)
    |> stub(:playcount, fn ^user, _time_range, _api -> {:error, "Last.fm API: something went wrong"} end)

    assert {:error, "Last.fm API: something went wrong"} == LastfmArchive.sync(user)
  end

  test "sync/2 handles time-range playcount API call error", %{user: user, archive: archive} do
    {registered_time, last_scrobble_time} = archive.temporal
    total_scrobbles = archive.extent
    api_error = "Operation failed - Most likely the backend service failed. Please try again."

    LastfmArchive.FileArchiveMock |> stub(:update_metadata, fn _archive, _options -> {:ok, archive} end)

    LastfmClientMock
    |> expect(:info, fn ^user, _api -> {:ok, {total_scrobbles, registered_time}} end)
    |> expect(:playcount, fn ^user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
    |> stub(:playcount, fn ^user, _time_range, _api -> {:error, api_error} end)

    sync_message = capture_io(fn -> LastfmArchive.sync(user) end)
    assert sync_message =~ "Last.fm API error while syncing"
    assert sync_message =~ api_error
  end

  test "sync/2 handles and caches scrobbles API call error", %{user: user, archive: archive} do
    daily_playcount = 13
    {registered_time, last_scrobble_time} = archive.temporal
    total_scrobbles = archive.extent
    api_error = "Operation failed - Most likely the backend service failed. Please try again."

    LastfmArchive.FileArchiveMock |> stub(:update_metadata, fn _archive, _options -> {:ok, archive} end)

    LastfmClientMock
    |> expect(:info, fn ^user, _api -> {:ok, {total_scrobbles, registered_time}} end)
    |> expect(:playcount, fn ^user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
    |> stub(:playcount, fn ^user, _time_range, _api -> {:ok, {daily_playcount, 0}} end)
    |> stub(:scrobbles, fn ^user, _page_params, _api -> {:error, api_error} end)

    LastfmArchive.CacheMock
    |> expect(:put, 3, fn {^user, 2021}, {_from, _to}, {^daily_playcount, [{:error, _data}]}, _cache -> :ok end)

    sync_message = capture_io(fn -> LastfmArchive.sync(user) end)
    assert sync_message =~ "x"
  end

  test "do not cache sync/2 of today's scrobbles" do
    registered_time = (DateTime.utc_now() |> DateTime.to_unix()) - 100
    last_scrobble_time = DateTime.utc_now() |> DateTime.to_unix()
    total_scrobbles = 2

    test_archive = %{
      Archive.new("a_lastfm_user")
      | temporal: {registered_time, last_scrobble_time},
        extent: total_scrobbles,
        date: Date.utc_today(),
        type: FileArchive
    }

    LastfmArchive.FileArchiveMock
    |> expect(:describe, fn _user, _options -> {:ok, test_archive} end)
    |> expect(:update_metadata, fn _archive, _options -> {:ok, test_archive} end)
    |> stub(:update_metadata, fn _updated_archive, _options -> {:ok, test_archive} end)

    LastfmClientMock
    |> expect(:info, fn _user, _api -> {:ok, {total_scrobbles, registered_time}} end)
    |> expect(:playcount, fn _user, _time_range, _api -> {:ok, {total_scrobbles, last_scrobble_time}} end)
    |> stub(:playcount, fn _user, _time_range, _api -> {:ok, {total_scrobbles, 0}} end)

    LastfmArchive.CacheMock
    |> expect(:put, 0, fn {_user, _year}, {_from, _to}, {^total_scrobbles, [:ok]}, _cache -> :ok end)

    capture_io(fn -> LastfmArchive.sync("a_lastfm_user") end)
  end
end
