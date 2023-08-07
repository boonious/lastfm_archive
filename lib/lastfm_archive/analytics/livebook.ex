defmodule LastfmArchive.Analytics.Livebook do
  @moduledoc false

  alias Explorer.DataFrame
  require Explorer.DataFrame

  import LastfmArchive.Analytics.Commons, only: [mutate_pivot_rows: 4]
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
      frequencies(df, ["artist", "year"]) |> collect() |> derive_stats("artist") |> finalise(),
      frequencies(df, ["album", "year"]) |> collect() |> derive_stats("album") |> finalise(),
      frequencies(df, ["name", "year"]) |> collect() |> derive_stats("name") |> finalise(10)
    }
    |> render()
  end

  defp derive_stats(df, group) do
    mutate_fun = fn df -> DataFrame.mutate(df, freq: count(year), total_plays: sum(counts)) end
    pivot_fun = fn df -> DataFrame.pivot_wider(df, "year", ["counts"]) end
    mutate_pivot_rows(df, group, mutate_fun, pivot_fun)
  end

  defp finalise(df, rows \\ 5) do
    df
    |> DataFrame.arrange(desc: total_plays)
    |> DataFrame.head(rows)
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> map_years(row) end)
  end

  defp collect(df), do: df |> DataFrame.collect()

  defp frequencies(df, ["album", "year"]) do
    df
    |> DataFrame.filter(album != "")
    |> DataFrame.frequencies(["album", "year"])
  end

  defp frequencies(df, columns), do: df |> DataFrame.frequencies(columns)

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
        for %{"album" => album, "years" => years} <- albums do
          count = years |> Map.values() |> Enum.sum()
          years = render_years(years)

          # "- **#{album}** <sup>#{count}x</sup> <br/> <small>by #{artist}</small> <br/>" <> years
          "- **#{album}** <sup>#{count}x</sup> <br/>" <> years
        end
      ]
      |> List.flatten()
      |> Enum.join("\n")

    tracks =
      [
        "#### Top tracks",
        for %{"name" => track, "years" => years} <- tracks do
          count = years |> Map.values() |> Enum.sum()
          years = render_years(years)

          # "- **#{track}** <sup>#{count}x</sup> <br/> <small> #{album} by #{artist}</small> <br/>" <> years
          "- **#{track}** <sup>#{count}x</sup> <br/>" <> years
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
