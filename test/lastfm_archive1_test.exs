defmodule LastfmArchive1Test do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias Lastfm.{Archive, FileArchive}

  doctest LastfmArchive1

  setup :verify_on_exit!

  describe "sync/1" do
    test "scrobbles to a new file archive" do
      user = "a_lastfm_user"
      metadata = LastfmArchive.Utils.metadata_path(user, [])

      total_scrobbles = 400
      registered_time = DateTime.from_iso8601("2020-08-31T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      last_scrobble_time = DateTime.from_iso8601("2021-04-05T18:50:07Z") |> elem(1) |> DateTime.to_unix()

      test_archive = %{
        Archive.new(user)
        | temporal: {registered_time, last_scrobble_time},
          extent: total_scrobbles,
          date: ~D[2021-04-05],
          type: FileArchive
      }

      Lastfm.FileArchiveMock
      |> expect(:describe, fn ^user, _options -> {:error, test_archive} end)
      |> expect(:create, fn ^test_archive, _options -> {:ok, test_archive} end)
      |> stub(:write, fn ^test_archive, _data, _options -> :ok end)

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {total_scrobbles, registered_time} end)
      |> expect(:playcount, fn ^user, _time_range, _api -> {total_scrobbles, last_scrobble_time} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {13, 0} end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      Lastfm.FileIOMock |> stub(:write, fn ^metadata, _archive -> :ok end)
      capture_io(fn -> LastfmArchive1.sync(user) end)
    end
  end
end
