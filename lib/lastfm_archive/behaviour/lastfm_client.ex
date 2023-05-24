defmodule LastfmArchive.Behaviour.LastfmClient do
  @moduledoc """
  Behaviour and data struct for retrieving data from Lastfm API.
  """

  alias LastfmArchive.LastfmClient

  @type client :: LastfmClient.t()

  @type user :: binary
  @type page :: integer
  @type limit :: integer
  @type from :: integer
  @type to :: integer

  @type playcount :: integer

  # epoch Unix times
  @type latest_scrobble_time :: integer
  @type registered_time :: integer

  @doc """
  Returns the scrobbles of a user for a given time range.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for more details.
  """
  @callback scrobbles(user, {page, limit, from, to}, client) :: {:ok, map} | {:error, term()}

  @doc """
  Returns the total playcount, registered, i.e. first scrobble time for a user.
  """
  @callback info(user, client) :: {:ok, {playcount, registered_time}} | {:error, term()}

  @doc """
  Returns the playcount and the latest scrobble date of a user for a given time range.
  """
  @callback playcount(user, {from, to}, client) :: {:ok, {playcount, latest_scrobble_time}} | {:error, term()}
end
