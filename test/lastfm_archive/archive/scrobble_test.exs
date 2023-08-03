defmodule LastfmArchive.Archive.ScrobbleTest do
  use ExUnit.Case, async: true
  import Fixtures.Lastfm
  alias LastfmArchive.Archive.Scrobble

  test "new/1 scrobble" do
    scrobbles = recent_tracks() |> Jason.decode!()
    scrobble = scrobbles["recenttracks"]["track"] |> hd

    assert %LastfmArchive.Archive.Scrobble{
             album_mbid: "0c022aea-1ee8-4664-9287-4482fe345e18",
             album: "Fading Like a Flower (Every Time You Leave)",
             artist_url: "https://www.last.fm/music/Roxette",
             artist_mbid: "d3b2711f-2baa-441a-be95-14945ca7e6ea",
             artist: "Roxette",
             url: "https://www.last.fm/music/Roxette/_/Physical+Fascination+(guitar+solo+version)",
             datetime: "2021-04-13 15:26:42Z",
             datetime_unix: 1_618_327_602,
             year: 2021,
             name: "Physical Fascination (guitar solo version)",
             mbid: "cd000775-0a7c-38ea-96ab-4dacfae789fe",
             id: _uuid
           } = Scrobble.new(scrobble)
  end

  test "new/1 scrobbles" do
    scrobbles = recent_tracks() |> Jason.decode!()
    assert [%LastfmArchive.Archive.Scrobble{}] = Scrobble.new(scrobbles) |> Enum.to_list()
  end
end
