defmodule LastfmArchive.Analytics.OnThisDayTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm
  import Hammox

  alias Explorer.DataFrame
  alias LastfmArchive.Analytics.OnThisDay
  alias LastfmArchive.Archive.DerivedArchiveMock

  setup :verify_on_exit!

  setup do
    user = LastfmArchive.default_user()
    today = Date.utc_today()

    file_archive_metadata =
      new_archive_metadata(
        user: user,
        start:
          DateTime.from_iso8601("#{today |> Date.add(-1) |> to_string()}T00:00:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("#{today |> Date.add(1) |> to_string()}T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: LastfmArchive.Archive.FileArchive
      )

    %{user: user, file_archive_metadata: file_archive_metadata}
  end

  describe "data_frame/1" do
    test "contains data on this day", %{user: user, file_archive_metadata: metadata} do
      options = [format: :ipc_stream]
      single_scrobble_on_this_day = recent_tracks_on_this_day(user)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^options -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame(single_scrobble_on_this_day)} end)

      assert %DataFrame{} = df = OnThisDay.data_frame(options) |> Explorer.DataFrame.collect()
      assert {1, _column_count} = df |> DataFrame.shape()
    end

    test "return no data without scrobble on this day", %{user: user, file_archive_metadata: metadata} do
      options = [format: :ipc_stream]
      not_now = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.to_unix()
      single_scrobble_not_on_this_day = recent_tracks_on_this_day(user, not_now)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^options -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^options -> {:ok, data_frame(single_scrobble_not_on_this_day)} end)

      assert %DataFrame{} = df = OnThisDay.data_frame(options) |> Explorer.DataFrame.collect()
      assert {0, _column_count} = df |> DataFrame.shape()
    end

    test "handles archive read error", %{user: user, file_archive_metadata: metadata} do
      options = [format: :ipc_stream]

      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^options -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^options -> {:error, :einval} end)

      assert {:error, :einval} = OnThisDay.data_frame(options)
    end
  end
end
