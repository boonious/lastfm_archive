defmodule LastfmArchive.Analytics.OnThisDayTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Fixtures.Lastfm
  import Hammox

  alias Explorer.DataFrame
  alias Explorer.Series

  alias LastfmArchive.Analytics.OnThisDay
  alias LastfmArchive.Analytics.Settings
  alias LastfmArchive.Archive.DerivedArchiveMock

  setup :verify_on_exit!

  setup_all do
    user = LastfmArchive.default_user()
    today = Date.utc_today()

    file_archive_metadata =
      new_archive_metadata(
        user: user,
        start:
          DateTime.from_iso8601("#{today |> Date.add(-1) |> to_string()}T00:00:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("#{today |> Date.add(1) |> to_string()}T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      )

    %{
      user: user,
      data_frame: user |> recent_tracks_on_this_day() |> data_frame() |> DataFrame.rename(name: "track"),
      file_archive_metadata: file_archive_metadata
    }
  end

  describe "data_frame/1" do
    setup do
      %{options: [format: :ipc_stream, columns: OnThisDay.columns()]}
    end

    test "contains data on this day", %{user: user, file_archive_metadata: metadata, options: opts} do
      single_scrobble_on_this_day = recent_tracks_on_this_day(user)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^opts -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^opts -> {:ok, data_frame(single_scrobble_on_this_day)} end)

      assert %DataFrame{} = df = OnThisDay.data_frame(format: opts[:format])
      assert {1, _column_count} = df |> DataFrame.collect() |> DataFrame.shape()
    end

    test "return no data without scrobble on this day", %{user: user, file_archive_metadata: metadata, options: opts} do
      not_now = DateTime.utc_now() |> DateTime.add(-5, :day) |> DateTime.to_unix()
      single_scrobble_not_on_this_day = recent_tracks_on_this_day(user, not_now)

      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^opts -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^opts -> {:ok, data_frame(single_scrobble_not_on_this_day)} end)

      assert %DataFrame{} = df = OnThisDay.data_frame(format: opts[:format])
      assert {0, _column_count} = df |> DataFrame.collect() |> DataFrame.shape()
    end

    test "handles archive read error", %{user: user, file_archive_metadata: metadata, options: opts} do
      DerivedArchiveMock
      |> expect(:describe, fn ^user, ^opts -> {:ok, metadata} end)
      |> expect(:read, fn ^metadata, ^opts -> {:error, :einval} end)

      assert {:error, :einval} = OnThisDay.data_frame(format: opts[:format])
    end
  end

  test "data_frame_stats/0", %{data_frame: df} do
    assert %{
             album: %{count: 1},
             artist: %{count: 1},
             datetime: %{count: 1},
             id: %{count: 1},
             track: %{count: 1},
             year: %{count: 1, max: 2023, min: 2023}
           } = df |> OnThisDay.data_frame_stats()
  end

  describe "this_day/1" do
    test "default day string" do
      day = Date.utc_today() |> Calendar.strftime("%m%d")
      assert ^day = OnThisDay.this_day()
    end

    test "other formatted day string" do
      day = Date.utc_today() |> Calendar.strftime("%B")
      assert ^day = OnThisDay.this_day("%B")
    end
  end

  test "render_overview/1", %{data_frame: df} do
    assert %Kino.Markdown{content: content} = OnThisDay.render_overview(df)
    assert content =~ "**1** scrobbles"
  end

  test "render_most_played/1", %{data_frame: df} do
    assert %Kino.Layout{} = OnThisDay.render_most_played(df)
  end

  for facet <- Settings.facets() do
    test "top_#{facet}s/2", %{data_frame: df} do
      facet = "#{unquote(facet)}"
      assert {%DataFrame{} = df_facets, facet_stats} = apply(OnThisDay, :"top_#{facet}s", [df])

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
