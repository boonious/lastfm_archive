defmodule LastfmArchive.Analytics.Livebook do
  @moduledoc false

  alias Explorer.DataFrame
  import LastfmArchive.Analytics.Commons, only: [most_played: 2]
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
    {
      most_played(df, ["artist", "year"]) |> collect(),
      most_played(df, ["album", "artist", "year"]) |> collect(),
      most_played(df, ["name", "album", "artist", "year"]) |> collect()
    }
    |> render()
  end

  defp collect(df, rows \\ 5) do
    df
    |> DataFrame.collect()
    |> DataFrame.pivot_wider("year", "playcount")
    |> DataFrame.head(rows)
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> map_years(row) end)
  end

  defp render({artists, albums, tracks}) do
    artists =
      [
        "#### Top artists",
        for %{"artist" => artist, "years" => years} <- artists do
          count = years |> Map.values() |> Enum.sum()
          years = render_years(years)

          "- **#{artist}** <sup>#{count}x</sup> <br/>" <> years
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    albums =
      [
        "#### Top albums",
        for %{"artist" => artist, "album" => album, "years" => years} <- albums do
          count = years |> Map.values() |> Enum.sum()
          years = render_years(years)

          "- **#{album}** <sup>#{count}x</sup> <br/> <small>by #{artist}</small> <br/>" <> years
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    tracks =
      [
        "#### Top tracks",
        for %{"name" => track, "artist" => artist, "album" => album, "years" => years} <- tracks do
          count = years |> Map.values() |> Enum.sum()
          years = render_years(years)

          "- **#{track}** <sup>#{count}x</sup> <br/> <small> #{album} by #{artist}</small> <br/>" <> years
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    [Kino.Markdown.new(artists), Kino.Markdown.new(albums), Kino.Markdown.new(tracks)]
    |> Kino.Layout.grid(columns: 3)
  end

  defp render_years(years) do
    for {year, _count} <- years do
      "<small>#{year}#{this_day()}</small>"
    end
    |> Enum.join(", ")
  end

  defp map_years(row) do
    Enum.flat_map(row, fn
      {_k, nil} -> []
      {k, v} -> if String.match?(k, ~r/^\d{4}$/), do: [{k, v}], else: []
    end)
    |> Enum.into(%{})
    |> then(fn years -> Map.put(row, "years", years) end)
  end
end
