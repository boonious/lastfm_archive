defmodule LastfmArchive.Analytics.Livebook do
  @moduledoc false

  use LastfmArchive.Behaviour.Analytics, facets: LastfmArchive.Analytics.Settings.available_facets()

  alias Explorer.DataFrame
  alias Explorer.Series

  require Explorer.DataFrame

  import LastfmArchive.Analytics.Commons, only: [frequencies: 2, create_group_stats: 2, create_facet_stats: 2]
  import LastfmArchive.Analytics.OnThisDay, only: [this_day: 0, this_day: 1]

  def render_overview(%DataFrame{} = df) do
    df
    |> DataFrame.collect()
    |> DataFrame.n_rows()
    |> then(fn total ->
      Kino.Markdown.new("""
      ###
      There are **#{total}** scrobbles on **#{this_day("%B %d")}** over the years.
      <br/><br/>
      """)
    end)
    |> Kino.render()
  end

  def render_most_played(df) do
    [top_artists(df), top_albums(df), top_tracks(df, rows: 10)] |> render()
  end

  defp render([artists_info, albums_info, tracks_info]) do
    {top_n, extra} = artists_info

    artists =
      [
        "#### Top artists",
        for {%{"artist" => artist, "total_plays" => count} = row, index} <-
              top_n |> DataFrame.to_rows() |> Enum.with_index() do
          "- **#{artist}** <sup>#{count}x</sup> <br/>" <>
            render_extra(extra[index], "artist") <> (row |> map_years() |> render_years())
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    {top_n, extra} = albums_info

    albums =
      [
        "#### Top albums",
        for {%{"album" => album, "total_plays" => count} = row, index} <-
              top_n |> DataFrame.to_rows() |> Enum.with_index() do
          "- **#{album}** <sup>#{count}x</sup> <br/>" <>
            render_extra(extra[index], "album") <> (row |> map_years() |> render_years())
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    {top_n, extra} = tracks_info

    tracks =
      [
        "#### Top tracks",
        for {%{"name" => track, "total_plays" => count} = row, index} <-
              top_n |> DataFrame.to_rows() |> Enum.with_index() do
          "- **#{track}** <sup>#{count}x</sup> <br/>" <>
            render_extra(extra[index], "track") <> (row |> map_years() |> render_years())
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    [Kino.Markdown.new(artists), Kino.Markdown.new(albums), Kino.Markdown.new(tracks)]
    |> Kino.Layout.grid(columns: 3)
  end

  defp map_years(row) do
    Enum.flat_map(row, fn
      {_k, nil} -> []
      {k, _v} -> if String.match?(k, ~r/^\d{4}$/), do: [k], else: []
    end)
  end

  defp render_years(years), do: for(year <- years, do: "<small>#{year}#{this_day()}</small>") |> Enum.join(", ")

  defp render_extra(extra, "artist") do
    %{"num_albums_played" => num_albums, "num_tracks_played" => num_tracks} =
      extra |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    "<small>#{item("album", num_albums)} , #{item("track", num_tracks)}</small> <br/>"
  end

  defp render_extra(extra, "album") do
    %{"num_artists_played" => num_artists, "num_tracks_played" => num_tracks} =
      extra |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    "<small>#{item("artist", num_artists, extra)} , #{item("track", num_tracks)}</small> <br/>"
  end

  defp render_extra(extra, "track") do
    item("track_album", extra |> DataFrame.n_rows(), extra) <> "<br/>"
  end

  defp item(type, num, extra \\ nil)

  defp item("track_album", num, extra) when num <= 2 do
    for %{"album" => album, "artist" => artist} <-
          extra |> DataFrame.select(["album", "artist"]) |> DataFrame.distinct() |> DataFrame.to_rows() do
      "<small>#{album} by #{artist}</small>"
    end
    |> Enum.join("<br/>")
  end

  defp item("track_album", _num, extra) do
    %{"num_artists_played" => num_artists, "num_albums_played" => num_albums} =
      extra |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    "<small>#{item("artist", num_artists)} , #{item("album", num_albums)}</small>"
  end

  defp item("artist", num, extra) when num <= 2 and extra != nil do
    artists =
      for(artist <- extra["artist"] |> Series.distinct() |> Series.to_list(), do: artist)
      |> Enum.join(", ")

    "by #{artists}"
  end

  defp item("artist", num, _extra), do: "#{num} various artists"

  defp item(type, 1, _extra), do: "1 #{type}"
  defp item(type, num, _extra), do: "#{num} #{type}s"
end
