defmodule LastfmArchive.ArchiveTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Archive
  import Fixtures.Archive

  describe "new/1" do
    test "from a new user" do
      assert %Archive{
        creator: "a_lastfm_user",
        created: %{__struct__: DateTime},
        description: "Lastfm archive of a_lastfm_user, extracted from Lastfm API",
        format: "application/json",
        identifier: "a_lastfm_user",
        source: "http://ws.audioscrobbler.com/2.0",
        title: "Lastfm archive of a_lastfm_user"
      } = Archive.new("a_lastfm_user")
    end

    test "from decoded metadata" do
      assert %Archive{
        created: ~U[2021-04-09 16:37:07.638844Z],
        creator: "lastfm_user",
        date: ~D[2023-06-09],
        description: "Lastfm archive of lastfm_user, extracted from Lastfm API",
        extent: 392448,
        format: "application/json",
        identifier: "lastfm_user",
        modified: "2023-06-09T14:36:16.952540Z",
        source: "http://ws.audioscrobbler.com/2.0",
        temporal: {1187279599, 1686321114},
        title: "Lastfm archive of lastfm_user",
        type: LastfmArchive.FileArchive
      } = Archive.new(archive_metadata() |> Jason.decode!(keys: :atoms!))
    end
  end

  test "new/3" do
    archive = Archive.new("a_lastfm_user")
    registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    latest_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    total_scrobbles = 400
    date = latest_scrobble_time |> DateTime.from_unix!() |> DateTime.to_date()

    assert %Archive{
             temporal: {^registered_time, ^latest_scrobble_time},
             extent: ^total_scrobbles,
             date: ^date
           } = Archive.new(archive, total_scrobbles, registered_time, latest_scrobble_time)
  end
end
