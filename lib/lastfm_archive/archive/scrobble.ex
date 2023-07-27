defmodule LastfmArchive.Archive.Scrobble do
  @moduledoc """
  Struct representing a Lastfm scrobble, i.e. listened track.
  """

  use TypedStruct

  @typedoc "Lastfm scrobble"
  typedstruct do
    field(:id, String.t())
    field(:mbid, String.t())
    field(:name, String.t())
    field(:url, String.t())

    field(:datetime_unix, integer())
    field(:datetime, String.t())
    field(:year, integer())

    field(:artist, String.t())
    field(:artist_mbid, String.t())
    field(:artist_url, String.t())

    field(:album, String.t())
    field(:album_mbid, String.t())
  end

  @doc """
  Create a single or stream of scrobble structs.
  """
  @spec new(map()) :: t() | Enumerable.t(t())
  def new(%{"recenttracks" => %{"track" => tracks}}) when is_list(tracks) do
    tracks
    |> Stream.flat_map(fn track ->
      case track["date"] do
        nil -> []
        _date -> [new(track)]
      end
    end)
  end

  def new(%{"name" => _} = track) do
    unix_time = track["date"]["uts"] |> String.to_integer()
    date_time = DateTime.from_unix!(unix_time)

    %__MODULE__{
      id: UUID.uuid4(),
      mbid: track["mbid"],
      name: track["name"],
      datetime_unix: unix_time,
      datetime: date_time |> DateTime.to_string(),
      year: date_time.year,
      url: track["url"],
      artist: track["artist"]["name"] || track["artist"]["#text"],
      artist_mbid: track["artist"]["mbid"],
      artist_url: track["artist"]["url"],
      album: track["album"]["#text"],
      album_mbid: track["album"]["mbid"]
    }
  end
end
