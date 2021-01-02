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

  @type lastfm_response :: {:ok, map} | {:error, binary, Hui.Error.t()}
  @type user :: binary

  @doc """
  Returns the total playcount and earliest scrobble date for a user.
  """
  @callback info(user, t) :: {integer, integer}

  @doc """
  Returns the playcount of a user for a given time range.
  """
  @callback playcount(user, {integer, integer}, t) :: integer
end
