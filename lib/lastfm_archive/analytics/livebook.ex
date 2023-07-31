defmodule LastfmArchive.Analytics.Livebook do
  @moduledoc false

  alias Explorer.DataFrame
  import LastfmArchive.Analytics.Commons, only: [most_played: 2]
  import LastfmArchive.Analytics.OnThisDay, only: [this_day: 0, this_day: 1]

  def most_played_this_day(df) do
    {
      df |> DataFrame.collect() |> DataFrame.n_rows(),
      most_played(df, ["artist", "year"]) |> collect(),
      most_played(df, ["album", "artist", "year"]) |> collect(),
      most_played(df, ["name", "album", "artist", "year"]) |> collect()
    }
    |> render()
  end

  defp collect(df) do
    df
    |> DataFrame.collect()
    |> DataFrame.to_rows()
  end

  defp render({total, artists, albums, tracks}) do
    Kino.Markdown.new("""
    ###
    On **#{this_day("%B %d")}** over the years, there are **#{total}** scrobbles.
    <br/><br/>
    """)
    |> Kino.render()

    artists =
      [
        "#### Top artists",
        for %{"artist" => artist, "playcount" => count, "year" => year} <- artists |> Enum.sort_by(& &1["year"], :desc) do
          "- **#{artist}** <sup>#{count}x</sup> <br/> <small>#{year}#{this_day()}</small>"
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    albums =
      [
        "#### Top albums",
        for %{"artist" => artist, "album" => album, "playcount" => count, "year" => year} <-
              albums |> Enum.sort_by(& &1["year"], :desc) do
          "- **#{album}** <sup>#{count}x</sup> <br/> <small>by #{artist}</small> <br/> <small>#{year}#{this_day()}</small>"
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    tracks =
      [
        "#### Top tracks",
        for %{"name" => track, "artist" => artist, "album" => album, "playcount" => count, "year" => year} <-
              tracks |> Enum.sort_by(& &1["year"], :desc) do
          "- **#{track}** <sup>#{count}x</sup> <br/> <small> #{album} by #{artist}</small> <br/> <small>#{year}#{this_day()}</small> "
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    [Kino.Markdown.new(artists), Kino.Markdown.new(albums), Kino.Markdown.new(tracks)]
    |> Kino.Layout.grid(columns: 3)
  end
end
