defmodule LastfmArchive.Analytics.CommonsTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm

  alias Explorer.DataFrame
  alias LastfmArchive.Analytics.Commons

  test "most_played/3" do
    user = LastfmArchive.default_user()
    single_scrobble_on_this_day = recent_tracks_on_this_day(user)
    df = data_frame(single_scrobble_on_this_day)

    assert %DataFrame{} = df = Commons.most_played(df, ["artist", "year"]) |> DataFrame.collect()
    assert {1, 3} == df |> DataFrame.shape()
  end
end
