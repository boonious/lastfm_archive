defmodule LastfmArchive.Analytics.LivebookTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm

  alias Explorer.DataFrame
  alias LastfmArchive.Analytics.Livebook, as: LFM_LB

  test "most_played_this_day/1" do
    df =
      LastfmArchive.default_user()
      |> recent_tracks_on_this_day()
      |> data_frame()

    assert %Kino.Layout{} = LFM_LB.most_played_this_day(df)
  end
end
