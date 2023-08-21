defmodule LastfmArchive.Behaviour.LivebookAnalytics do
  @moduledoc """
  Behaviour and default implementation of a Livebook analytics UI.
  """

  alias Explorer.DataFrame
  alias Explorer.Series

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
          "#### ",
          "#### #{facet_type |> String.capitalize()}s",
          for {row, index} <- facets |> DataFrame.to_rows() |> Enum.with_index() do
            count = row["total_plays"] || row["counts"]
            type = if facet_type == "track", do: "name", else: facet_type

            "#{index + 1}. **#{row[type]}** <sup>#{count}x</sup> <br/>" <> render(stats[index], facet_type)
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
      stats |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    [
      "<small>#{item("album", num_albums)} , #{item("track", num_tracks)}</small>",
      for(year <- stats["year"] |> to_list(), do: "<small>#{year}</small>") |> Enum.join(", ")
    ]
    |> Enum.join("<br/>")
  end

  def render(stats, "album") do
    %{"num_artists_played" => num_artists, "num_tracks_played" => num_tracks} =
      stats |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    [
      "<small>#{item("artist", num_artists, stats)} , #{item("track", num_tracks)}</small>",
      for(year <- stats["year"] |> to_list(), do: "<small>#{year}</small>") |> Enum.join(", ")
    ]
    |> Enum.join("<br/>")
  end

  def render(stats, "track") do
    item("track_album", stats |> DataFrame.n_rows(), stats) <> "<br/>"
  end

  def item(type, num, stats \\ nil)

  def item("track_album", num, stats) when num <= 3 do
    [
      for %{"album" => album, "artist" => artist} <-
            stats
            |> DataFrame.select(["album", "artist"])
            |> DataFrame.distinct()
            |> DataFrame.to_rows() do
        "<small>#{album} by #{artist}</small>"
      end
      |> Enum.join("<br/>"),
      for(year <- stats["year"] |> to_list(), do: "<small>#{year}</small>") |> Enum.join(", ")
    ]
    |> Enum.join("<br/>")
  end

  def item("track_album", _num, stats) do
    %{"num_artists_played" => num_artists, "num_albums_played" => num_albums} =
      stats |> DataFrame.head(1) |> DataFrame.to_rows() |> hd

    [
      "<small>#{item("artist", num_artists)} , #{item("album", num_albums)}</small>",
      for(year <- stats["year"] |> to_list(), do: "<small>#{year}</small>") |> Enum.join(", ")
    ]
    |> Enum.join("<br/>")
  end

  def item("artist", num, stats) when num <= 2 and stats != nil do
    for(artist <- stats["artist"] |> to_list(), do: artist)
    |> Enum.join(", ")
    |> then(&"by #{&1}")
  end

  def item("artist", num, _stats), do: "#{num} various artists"
  def item(type, 1, _stats), do: "1 #{type}"
  def item(type, num, _stats), do: "#{num} #{type}s"

  defp to_list(%Series{} = series), do: series |> Series.distinct() |> Series.to_list()
end
