defmodule LastfmArchiveTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import TestHelpers

  doctest LastfmArchive

  # testing with Bypass
  setup do
    lastfm_ws = Application.get_env :elixirfm, :lastfm_ws

    # true if mix test --include integration
    is_integration = :integration in ExUnit.configuration[:include]
    bypass = unless is_integration, do: Bypass.open, else: nil

    on_exit fn ->
      Application.put_env :elixirfm, :lastfm_ws, lastfm_ws
    end

    [bypass: bypass]
  end

  test "archive user", %{bypass: bypass} do
    if(bypass) do
      user = Application.get_env(:lastfm_archive, :user)
      api_key = Application.get_env(:elixirfm, :api_key)
      prebaked_resp = File.read!("./test/data/test_user.json")

      test_conn_params(bypass,  %{"method" => "user.getinfo","api_key" => api_key, "user" => user}, prebaked_resp)
      assert capture_io(fn -> LastfmArchive.archive(user,0) end)
        ==  """
            Archiving Lastfm scrobble data for #{user}

            Archiving year: 2016-01-01 - 2016-12-31

            Archiving year: 2017-01-01 - 2017-12-31

            Archiving year: 2018-01-01 - 2018-12-31
            """
    end
  end

end
