defmodule LastfmArchive.Archive.ScrobbleTest do
  use ExUnit.Case, async: true
  import LastfmArchive.Factory, only: [build: 2]
  alias LastfmArchive.Archive.Scrobble

  test "new/1 scrobble" do
    [track] = build(:recent_tracks, num_of_plays: 1)["recenttracks"]["track"]

    assert %Scrobble{} = scrobble = Scrobble.new(track)
    assert scrobble.album == track["album"]["#text"]
    assert scrobble.album_mbid == track["album"]["mbid"]

    assert scrobble.artist == track["artist"]["name"]
    assert scrobble.artist_mbid == track["artist"]["mbid"]
    assert scrobble.artist_url == track["artist"]["url"]

    unix_time = track["date"]["uts"] |> String.to_integer()
    datetime = DateTime.from_unix!(unix_time)

    assert scrobble.datetime_unix == unix_time
    assert scrobble.datetime == datetime |> DateTime.to_naive()
    assert scrobble.year == datetime.year
    assert scrobble.mmdd == datetime |> Calendar.strftime("%m%d")
    assert scrobble.date == datetime |> DateTime.to_date()

    assert scrobble.name == track["name"]
    assert scrobble.mbid == track["mbid"]
    assert scrobble.url == track["url"]
  end

  test "new/1 scrobbles" do
    scrobbles = build(:recent_tracks, num_of_plays: 1)
    assert [%LastfmArchive.Archive.Scrobble{}] = Scrobble.new(scrobbles) |> Enum.to_list()
  end
end
