defmodule LastfmArchive.Analytics.LivebookTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm

  alias Explorer.DataFrame
  alias Explorer.Series

  alias LastfmArchive.Analytics.Livebook, as: LFM_LB
  alias LastfmArchive.Analytics.Settings

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

  for facet <- Settings.available_facets() do
    test "top_#{facet}s/2", %{data_frame: df} do
      facet = unquote(facet)
      assert {%DataFrame{} = df_facets, facet_stats} = apply(LFM_LB, :"top_#{facet}s", [df])

      facet = if facet == :track, do: "name", else: "#{facet}"
      assert facet in (df_facets |> DataFrame.names())
      assert "year" not in (df_facets |> DataFrame.names())
      assert df_facets["2023"] |> Series.to_list() == [1]
      assert df_facets["years_freq"] |> Series.to_list() == [1]
      assert df_facets["total_plays"] |> Series.to_list() == [1]

      assert %{0 => %DataFrame{} = _stats} = facet_stats
      # more test required for stats later
    end
  end
end
