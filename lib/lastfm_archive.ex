defmodule LastfmArchive do
  @moduledoc """
  Documentation for LastfmArchive.
  """

  import Elixirfm.User

  @doc """
  """
  @spec extract :: Elixirfm.response
  def extract, do: extract(Application.get_env(:lastfm_archive, :user))

  @doc """
  """
  @spec extract(binary) :: Elixirfm.response
  def extract(user), do: get_recent_tracks(user)

end
