defmodule LastfmArchive1Test do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox

  alias Lastfm.{Archive, FileArchive}
  alias LastfmArchive.Utils

  doctest LastfmArchive1

  setup :verify_on_exit!

  describe "sync/1" do
    test "scrobbles to a new file archive" do
      user = "a_lastfm_user"
      metadata = Utils.metadata(user, [])
      sync_result_cache = Utils.sync_result_cache("2021", user, [])

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
      |> expect(:describe, fn ^user, _options -> {:error, test_archive} end)
      |> expect(:update_metadata, fn ^test_archive, _options -> {:ok, test_archive} end)
      |> stub(:write, fn ^test_archive, _data, _options -> :ok end)

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {total_scrobbles, registered_time} end)
      |> expect(:playcount, fn ^user, _time_range, _api -> {total_scrobbles, last_scrobble_time} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> {daily_playcount, 0} end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      sync_results =
        %{
          {1_617_235_200, 1_617_321_599} => {daily_playcount, [:ok]},
          {1_617_321_600, 1_617_407_999} => {daily_playcount, [:ok]},
          {1_617_408_000, 1_617_494_399} => {daily_playcount, [:ok]}
        }
        |> :erlang.term_to_binary()

      Lastfm.FileIOMock
      |> expect(:read, fn ^sync_result_cache -> %{} |> :erlang.term_to_binary() end)
      |> expect(:write, fn ^sync_result_cache, ^sync_results -> :ok end)
      |> expect(:write, fn ^metadata, _archive -> :ok end)

      capture_io(fn -> LastfmArchive1.sync(user) end)
    end
  end
end
