defmodule LastfmArchive1Test do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import Mox

  alias Lastfm.{Archive, FileArchive}

  doctest LastfmArchive1

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    stub_with(Lastfm.ClientMock, Lastfm.ClientStub)
    stub_with(Lastfm.FileArchiveMock, Lastfm.FileArchiveStub)
    stub_with(LastfmArchive.CacheMock, LastfmArchive.CacheStub)

    :ok
  end

  describe "sync/1" do
    test "scrobbles to a new file archive" do
      user = "a_lastfm_user"

      total_scrobbles = 400
      daily_playcount = 13
      registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      last_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

      test_archive = %{
        Archive.new(user)
        | temporal: {registered_time, last_scrobble_time},
          extent: total_scrobbles,
          date: ~D[2021-04-03],
          type: FileArchive
      }

      Lastfm.FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:ok, test_archive} end)
      |> expect(:update_metadata, fn ^test_archive, _options -> {:ok, test_archive} end)
      |> stub(:update_metadata, fn _updated_archive, _options -> {:ok, test_archive} end)

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {total_scrobbles, registered_time} end)
      |> expect(:playcount, fn ^user, _time_range, _api -> {total_scrobbles, last_scrobble_time} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {daily_playcount, 0} end)

      capture_io(fn -> LastfmArchive1.sync(user) end)
    end
  end
end
