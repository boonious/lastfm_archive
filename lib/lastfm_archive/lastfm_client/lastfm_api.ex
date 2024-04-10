defmodule LastfmArchive.LastfmClient.LastfmApi do
  @moduledoc """
  Struct representing Lastfm API.
  """

  use TypedStruct
  import LastfmArchive.Configs, only: [lastfm_api_endpoint: 0, lastfm_api_key: 0, lastfm_api_method: 0, lastfm_user: 0]

  @typedoc "Lastfm API"
  typedstruct do
    field(:endpoint, String.t(), default: lastfm_api_endpoint(), enforce: true)
    field(:key, String.t(), enforce: true)
    field(:method, String.t(), default: lastfm_api_method(), enforce: true)
    field(:user, String.t(), default: lastfm_user())
    field(:format, String.t(), default: "json")

    field(:limit, integer(), default: 1)
    field(:page, integer(), default: 1)
    field(:from, integer())
    field(:to, integer())
    field(:extended, integer())
  end

  def new(method \\ lastfm_api_method()) do
    %__MODULE__{endpoint: lastfm_api_endpoint(), key: lastfm_api_key(), method: method}
  end
end

defimpl String.Chars, for: LastfmArchive.LastfmClient.LastfmApi do
  @basic_params [:method, :user, :format]
  @pagination_params [:limit, :page, :from, :to, :extended]

  def to_string(%{method: "user.getinfo"} = lfm_api) do
    IO.iodata_to_binary([
      lfm_api.endpoint,
      "?",
      "api_key=#{lfm_api.key}",
      build_query(lfm_api, @basic_params)
    ])
  end

  def to_string(%{method: "user.getrecenttracks"} = lfm_api) do
    IO.iodata_to_binary([
      lfm_api.endpoint,
      "?",
      "api_key=#{lfm_api.key}",
      build_query(lfm_api, @basic_params),
      build_query(lfm_api, @pagination_params)
    ])
  end

  defp build_query(lfm_api, params) do
    for k <- params do
      v = get_in(lfm_api, [Access.key!(k)])
      if(v, do: ["&", "#{k}=#{v}"], else: [])
    end
  end
end
