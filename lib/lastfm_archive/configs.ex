defmodule LastfmArchive.Configs do
  @moduledoc false

  def lastfm_api, do: Application.get_env(:lastfm_archive, :lastfm_api, %{})

  def lastfm_api_endpoint, do: System.get_env("LB_LFM_API_ENDPOINT") || "https://ws.audioscrobbler.com/2.0/"
  def lastfm_api_method, do: "user.getrecenttracks"
  def lastfm_api_key, do: System.get_env("LB_LFM_API_KEY") || lastfm_api()[:key] || ""

  def lastfm_user, do: System.get_env("LB_LFM_USER") || Application.get_env(:lastfm_archive, :user)
end
