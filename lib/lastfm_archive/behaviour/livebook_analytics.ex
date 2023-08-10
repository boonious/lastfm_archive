defmodule LastfmArchive.Behaviour.LivebookAnalytics do
  @moduledoc """
  Behaviour and default implementation of a Livebook analytics UI.
  """

  import LastfmArchive.Analytics.Settings

  @type data_frame :: LastfmArchive.Behaviour.Analytics.data_frame()
  @type data_frame_stats :: LastfmArchive.Behaviour.Analytics.data_frame_stats()
  @type facets :: LastfmArchive.Behaviour.Analytics.facets()
  @type kino_ui :: Kino.Markdown.t() | struct()
  @type options :: keyword()

  @callback overview(data_frame_stats()) :: kino_ui()
  @callback most_played_ui(facets(), options) :: kino_ui()

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LastfmArchive.Behaviour.LivebookAnalytics
      import LastfmArchive.Behaviour.LivebookAnalytics

      @impl true
      def overview(df), do: overview(df)

      @impl true
      def most_played_ui({facets, %{"type" => facet_type} = stats}, options \\ []) do
        facet_type = "#{facet_type}"

        [
          "#### #{facet_type |> String.capitalize()}s",
          for {%{"total_plays" => count} = row, index} <- facets |> Explorer.DataFrame.to_rows() |> Enum.with_index() do
            type = if facet_type == "track", do: "name", else: facet_type

            "- **#{row[type]}** <sup>#{count}x</sup> <br/>" <>
              render(stats[index], facet_type) <> (row |> map_years() |> render_years())
          end
        ]
        |> List.flatten()
        |> Enum.join("\n")
        |> Kino.Markdown.new()
      end

      defoverridable most_played_ui: 2
    end
  end

  def overview_ui(df_stats) do
    Kino.Markdown.new("""
    ###
    There are **#{df_stats.id.count}** scrobbles on **#{Date.utc_today() |> Calendar.strftime("%B %d")}**,
    over **#{df_stats.year.count}** years
    (earliest **#{df_stats.year.min}**, latest  **#{df_stats.year.max}**):
    - **#{df_stats.album.count}** albums, **#{df_stats.artist.count}** artists, **#{df_stats.name.count}** tracks
    <br/><br/>
    """)
  end

  def render(stats, "artist") do
    %{"num_albums_played" => num_albums, "num_tracks_played" => num_tracks} =
      stats |> Explorer.DataFrame.head(1) |> Explorer.DataFrame.to_rows() |> hd

    "<small>#{item("album", num_albums)} , #{item("track", num_tracks)}</small> <br/>"
  end

  def render(stats, "album") do
    %{"num_artists_played" => num_artists, "num_tracks_played" => num_tracks} =
      stats |> Explorer.DataFrame.head(1) |> Explorer.DataFrame.to_rows() |> hd

    "<small>#{item("artist", num_artists, stats)} , #{item("track", num_tracks)}</small> <br/>"
  end

  def render(stats, "track") do
    item("track_album", stats |> Explorer.DataFrame.n_rows(), stats) <> "<br/>"
  end

  def map_years(row) do
    Enum.flat_map(row, fn
      {_k, nil} -> []
      {k, _v} -> if String.match?(k, ~r/^\d{4}$/), do: [k], else: []
    end)
  end

  def render_years(years) do
    for(year <- years, do: "<small>#{year}#{Date.utc_today() |> Calendar.strftime("-%m-%d")}</small>")
    |> Enum.join(", ")
  end

  def item(type, num, stats \\ nil)

  def item("track_album", num, stats) when num <= 2 do
    for %{"album" => album, "artist" => artist} <-
          stats
          |> Explorer.DataFrame.select(["album", "artist"])
          |> Explorer.DataFrame.distinct()
          |> Explorer.DataFrame.to_rows() do
      "<small>#{album} by #{artist}</small>"
    end
    |> Enum.join("<br/>")
  end

  def item("track_album", _num, stats) do
    %{"num_artists_played" => num_artists, "num_albums_played" => num_albums} =
      stats |> Explorer.DataFrame.head(1) |> Explorer.DataFrame.to_rows() |> hd

    "<small>#{item("artist", num_artists)} , #{item("album", num_albums)}</small>"
  end

  def item("artist", num, stats) when num <= 2 and stats != nil do
    artists =
      for(artist <- stats["artist"] |> Explorer.Series.distinct() |> Explorer.Series.to_list(), do: artist)
      |> Enum.join(", ")

    "by #{artists}"
  end

  def item("artist", num, _stats), do: "#{num} various artists"
  def item(type, 1, _stats), do: "1 #{type}"
  def item(type, num, _stats), do: "#{num} #{type}s"
end
