defmodule LastfmArchive.Transform do
  @moduledoc """
  This module provides functions for reading and transforming downloaded Lastfm data.

  """

  @default_data_dir "./lastfm_data/"
  @default_delimiter "\t"

  @doc """
  Transform a downloaded raw JSON page into a list of tab-delimited track data.

  ### Example
  ```
    # transform a page of scrobbles from the file archive
    LastfmArchive.transform("a_lastfm_user", "2007/200_1.gz")
  ```

  A row of tab-delimited track currently contains (if any):

  - `id` auto-generated by the system to uniquely identify a scrobble
  - `name` the track name
  - `date` Unix timestamp of the scrobble date
  - `date_iso` scrobble date in ISO 8601 datetime format
  - `mbid` MusicBrainz identifier for the track
  - `url` web address of the track on Last.fm
  - `artist`
  - `artist_mbid` MusicBrainz identifier for the artist
  - `artist_url` web address of the artist on Last.fm
  - `album`
  - `album_mbid` MusicBrainz identifier for the album

  """
  @spec transform(binary, binary, :atom) :: list(binary) | {:error, :file.posix}
  def transform(user, filename, mode \\ :tsv)
  def transform(user, filename, :tsv) do
    {status, tracks_data} = read(user, filename)

    case status do
      :ok ->
        index = initial_index(tracks_data["recenttracks"]["@attr"])
        [track | tracks] = tracks_data["recenttracks"]["track"]
        if track["@attr"]["nowplaying"], do: _transform(user, tracks, index, []), else: _transform(user, [track | tracks], index, [])
      :error ->
        {:error, tracks_data}
    end
  end

  defp _transform(_user, [], _index, acc), do: acc
  defp _transform(user, [track|tracks], index, acc) do
    next_index = index + 1
    _transform(user, tracks, next_index, acc ++ [_transform(user, track, index)])
  end

  # id,name,scrobble_date,date_iso,mbid,url,artist,artist_mbid,artist_url,album,album_mbid
  defp _transform(user, track, index) do
    id = "#{user}_#{track["date"]["uts"]}_#{index |> to_string}"
    date_s = track["date"]["uts"] |> String.to_integer |> DateTime.from_unix! |> DateTime.to_iso8601

    track_info = [ id, track["name"] |> String.trim, track["date"]["uts"], date_s, track["mbid"], track["url"] ]
    artist_info = [ track["artist"]["name"],  track["artist"]["mbid"], track["artist"]["url"]]
    album_info = [ track["album"]["#text"],  track["album"]["mbid"]]
    Enum.join(track_info ++ artist_info ++ album_info, @default_delimiter)
  end

  @doc """
  Read and parse a raw Lastfm JSON file from the archive for a Lastfm user.
  """
  @spec read(binary, binary) :: {:ok, map} | {:error, :file.posix}
  def read(user, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join data_dir, user
    file_path = Path.join user_data_dir, filename

    {status, file_io} = File.open(file_path, [:read, :compressed, :utf8])

    resp = case status do
      :ok ->
        {:ok, IO.read(file_io, :line) |> Poison.decode!}
      :error ->
        {:error, file_io}
    end

    if is_pid(file_io), do: File.close(file_io)
    resp
  end

  defp initial_index(info), do: ((String.to_integer(info["page"]) - 1) * String.to_integer(info["perPage"])) + 1

end
