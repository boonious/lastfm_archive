defmodule LastfmArchive.Archive.MetadataTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Archive.Metadata
  import LastfmArchive.Factory, only: [build: 1]

  describe "new/1" do
    test "from a new user" do
      assert %Metadata{
               creator: "a_lastfm_user",
               created: %{__struct__: DateTime},
               description: "Lastfm archive of a_lastfm_user, extracted from Lastfm API",
               format: "application/json",
               identifier: "a_lastfm_user",
               source: "http://ws.audioscrobbler.com/2.0",
               title: "Lastfm archive of a_lastfm_user"
             } = Metadata.new("a_lastfm_user")
    end

    test "from decoded metadata" do
      metadata = build(:file_archive_metadata) |> Jason.encode!()

      assert %Metadata{
               created: _now,
               creator: "a_lastfm_user",
               date: ~D[2021-04-03],
               description: "Lastfm archive of a_lastfm_user, extracted from Lastfm API",
               extent: 388,
               format: "application/json",
               identifier: "a_lastfm_user",
               modified: "2023-06-09T14:36:16.952540Z",
               source: "http://ws.audioscrobbler.com/2.0",
               temporal: {1_617_303_007, 1_617_475_807},
               title: "Lastfm archive of a_lastfm_user",
               type: :scrobbles
             } = Metadata.new(metadata |> Jason.decode!(keys: :atoms!))
    end
  end

  test "new/3" do
    archive = Metadata.new("a_lastfm_user")
    registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    latest_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    total_scrobbles = 400
    date = latest_scrobble_time |> DateTime.from_unix!() |> DateTime.to_date()

    assert %Metadata{
             temporal: {^registered_time, ^latest_scrobble_time},
             extent: ^total_scrobbles,
             date: ^date
           } = Metadata.new(archive, total_scrobbles, {registered_time, latest_scrobble_time})
  end
end
