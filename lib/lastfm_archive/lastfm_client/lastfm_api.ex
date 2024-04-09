defmodule LastfmArchive.LastfmClient.LastfmApi do
  @moduledoc """
  Struct representing Lastfm API.
  """

  use TypedStruct
  import LastfmArchive.Configs, only: [lastfm_api_endpoint: 0, lastfm_api_key: 0, lastfm_api_method: 0, lastfm_user: 0]

  @typedoc "Lastfm API"
  typedstruct enforce: true do
    field(:key, String.t())
    field(:endpoint, String.t(), default: lastfm_api_endpoint())
    field(:method, String.t(), default: lastfm_api_method())
    field(:user, String.t(), default: lastfm_user())
  end

  def new(method \\ lastfm_api_method()) do
    %__MODULE__{endpoint: lastfm_api_endpoint(), key: lastfm_api_key(), method: method}
  end
end
