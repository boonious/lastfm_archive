defmodule ExtractTest do
  use ExUnit.Case, async: true
  import TestHelpers

  doctest LastfmArchive

  @lastfm_api_params %{"method" => "user.getrecenttracks", 
                       "api_key" => Application.get_env(:elixirfm, :api_key), 
                       "user" => Application.get_env(:lastfm_archive, :user)}

  # testing with Bypass default
  setup do
    lastfm_ws = Application.get_env :elixirfm, :lastfm_ws
    bypass = Bypass.open
    on_exit fn ->
      Application.put_env :elixirfm, :lastfm_ws, lastfm_ws
    end
    [bypass: bypass]
  end

  test "extract/0 requests params for the configured user", context do
    test_conn_params(context.bypass, @lastfm_api_params)
    LastfmArchive.extract
  end

  test "extract/1 requests params for a specific user", context do
    test_conn_params(context.bypass, %{@lastfm_api_params | "user" => "a_lastfm_user"})
    LastfmArchive.extract("a_lastfm_user")
  end

end
