defmodule Lastfm.Client do
  @moduledoc """
  A behaviour module for retrieving data from Lastfm via its API.
  """

  @api Application.get_env(:lastfm_archive, :api)

  defstruct api_key: @api[:api_key] || "",
            endpoint: @api[:endpoint] || "",
            method: @api[:method] || ""

  @type t :: %__MODULE__{
          api_key: binary,
          endpoint: binary,
          method: binary
        }

  @type user :: binary
  @type page :: integer
  @type limit :: integer
  @type from :: integer
  @type to :: integer

  @doc """
  Returns the scrobbles of a user for a given time range.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for more details.
  """
  @callback scrobbles(user, {page, limit, from, to}, t) :: {:ok, map} | {:error, term()}

  @doc """
  Returns the total playcount, registered time for a user.
  """
  @callback info(user, t) :: {:ok, {integer, integer}} | {:error, term()}

  @doc """
  Returns the playcount and the latest scrobble date of a user for a given time range.
  """
  @callback playcount(user, {from, to}, t) :: {:ok, {integer, integer}} | {:error, term()}
end
