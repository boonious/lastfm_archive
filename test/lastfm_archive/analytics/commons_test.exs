defmodule LastfmArchive.Analytics.CommonsTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm

  alias Explorer.DataFrame
  alias Explorer.Series
  alias LastfmArchive.Analytics.Commons

  setup_all do
    %{data_frame: LastfmArchive.default_user() |> recent_tracks_on_this_day() |> data_frame()}
  end

  describe "frequencies/2" do
    test "for a data frame", %{data_frame: df} do
      group = ["artist", "year"]

      assert %Explorer.DataFrame{} = df = Commons.frequencies(df, group) |> DataFrame.collect()
      assert df |> DataFrame.names() == group ++ ["counts"]
      assert df["counts"] |> Series.to_list() == [1]
    end

    test "filter option to exclude untitled albums" do
      df = recent_tracks_without_album_title() |> data_frame()
      filter_fun = &Series.not_equal(&1["album"], "")

      group = ["album", "year"]
      assert %Explorer.DataFrame{} = df = Commons.frequencies(df, group, filter: filter_fun) |> DataFrame.collect()
      assert df["counts"] |> Series.to_list() == []

      group = "album"
      assert %Explorer.DataFrame{} = df = Commons.frequencies(df, group, filter: filter_fun) |> DataFrame.collect()
      assert df["counts"] |> Series.to_list() == []
    end
  end

  test "create_group_stats/2", %{data_frame: df} do
    group = "album"
    df_freq = Commons.frequencies(df, [group, "year"])

    assert %Explorer.DataFrame{} = df = Commons.create_group_stats(df_freq, group)
    assert df["2023"] |> Series.to_list() == [1]
    assert df["years_freq"] |> Series.to_list() == [1]
    assert df["total_plays"] |> Series.to_list() == [1]
    assert "album" in (df |> DataFrame.names())
    assert "year" not in (df |> DataFrame.names())
  end

  test "most_played/2", %{data_frame: df} do
    group = "album"
    df = Commons.frequencies(df, [group, "year"]) |> Commons.create_group_stats(group)
    assert %Explorer.DataFrame{} = Commons.most_played(df)
  end
end
