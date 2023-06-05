defmodule LastfmArchive.Livebook do
  @moduledoc """
  Livebook chart and text rendering.
  """

  @doc """
  Display user name and total number of scrobbles to archive.
  """
  @spec info :: Kino.Markdown.t()
  def info do
    case {LastfmArchive.LastfmClient.default_user(), LastfmArchive.info()} do
      {"", _} ->
        Kino.Markdown.new("""
        Please specify a Lastfm user in configuration.
        """)

      {user, {:ok, {total, _}}} ->
        Kino.Markdown.new("""
        For Lastfm user: **#{user}** with **#{total}** total number of scrobbles.
        """)

      {_, _} ->
        Kino.Markdown.new("""
        Unable to fetch user info from Lastfm API, have you configured the API key?
        """)
    end
  end
end
