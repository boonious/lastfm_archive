defmodule LastfmArchive.LastfmClient.LastfmApi do
  @moduledoc """
  Struct representing Lastfm API.
  """

  use TypedStruct

  @endpoint "https://ws.audioscrobbler.com/"
  @method "user.getrecenttracks"

  @lastfm_api_key Application.compile_env(:lastfm_archive, :lastfm_api_key, "")

  @typedoc "Lastfm API"
  typedstruct enforce: true do
    field(:key, String.t())
    field(:endpoint, String.t(), default: @endpoint)
    field(:method, String.t(), default: @method)
  end

  def new(method \\ @method) do
    %__MODULE__{
      key: System.get_env("LB_LFM_API_KEY") || @lastfm_api_key || "",
      endpoint: System.get_env("LB_LFM_API_ENDPOINT") || @endpoint || "",
      method: method
    }
  end
end
