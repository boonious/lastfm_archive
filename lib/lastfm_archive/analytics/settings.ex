defmodule LastfmArchive.Analytics.Settings do
  @moduledoc false

  import Explorer.Series, only: [count: 1, distinct: 1]

  def available_facets, do: facet_mutation_fun() |> Map.keys()

  def facet_mutation_fun do
    %{
      album:
        &[num_artists_played: distinct(&1["artist"]) |> count(), num_tracks_played: distinct(&1["name"]) |> count()],
      artist:
        &[num_albums_played: distinct(&1["album"]) |> count(), num_tracks_played: distinct(&1["name"]) |> count()],
      track:
        &[num_albums_played: distinct(&1["album"]) |> count(), num_artists_played: distinct(&1["artist"]) |> count()]
    }
  end

  # generate these functions later
  def facet_type(%{"album" => _}), do: :album
  def facet_type(%{"artist" => _}), do: :artist
  def facet_type(%{"name" => _}), do: :track
end
