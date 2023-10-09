defmodule LastfmArchive.LastfmClient.LastfmApiTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.LastfmClient.LastfmApi

  test "new/0" do
    assert %LastfmApi{
             method: "user.getrecenttracks",
             endpoint: "https://ws.audioscrobbler.com/",
             key: ""
           } = LastfmApi.new()
  end

  test "new/1" do
    api_method = "another_lastfm_api_method"

    assert %LastfmApi{
             method: ^api_method,
             endpoint: "https://ws.audioscrobbler.com/",
             key: ""
           } = LastfmApi.new(api_method)
  end
end
