defmodule LastfmArchive.Analytics.LivebookTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm

  alias LastfmArchive.Analytics.Livebook, as: LFM_LB

  setup do
    %{data_frame: LastfmArchive.default_user() |> recent_tracks_on_this_day() |> data_frame()}
  end

  test "render_overview/1", %{data_frame: df} do
    assert %Kino.Markdown{content: content} = LFM_LB.render_overview(df)
    assert content =~ "**1** scrobbles"
  end

  test "render_most_played/1", %{data_frame: df} do
    assert %Kino.Layout{} = LFM_LB.render_most_played(df)
  end
end
