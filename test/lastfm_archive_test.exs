defmodule LastfmArchiveTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import TestHelpers

  doctest LastfmArchive

  @test_data_dir Path.join([".", "lastfm_data", "test", "archive"])
  @interval Application.get_env(:lastfm_archive, :interval) || 500

  # testing with Bypass
  setup do
    lastfm_ws = Application.get_env :elixirfm, :lastfm_ws
    configured_dir = Application.get_env :lastfm_archive, :data_dir

    # true if mix test --include integration
    is_integration = :integration in ExUnit.configuration[:include]
    bypass = unless is_integration, do: Bypass.open, else: nil

    on_exit fn ->
      Application.put_env :elixirfm, :lastfm_ws, lastfm_ws
      Application.put_env :lastfm_archive, :data_dir, configured_dir
    end

    [bypass: bypass]
  end

  @tag :disk_write
  test "archive scrobbles of the configured user - archive/0", %{bypass: bypass} do
    # Bypass test only
    if(bypass) do
      user = Application.get_env(:lastfm_archive, :user)
      
      # speed up this test
      # no requirement for 'interval' beetween requests
      # as per rate limit
      # since Bypass test is not hitting Lastfm API
      Application.put_env :lastfm_archive, :interval, 1

      prebaked_resp = %{"info" => "./test/data/test_user.json", "recenttracks" => "./test/data/test_recenttracks_no_scrobble.json"}
      test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "1"), user, prebaked_resp)
      capture_io(fn -> LastfmArchive.archive end)

      today = Date.utc_today
      year_s = today.year |> to_string
      no_scrobble_log_file = Path.join [@test_data_dir, "1", user, year_s, ".no_scrobble"]
      assert File.exists? no_scrobble_log_file
    end
  after
    Application.put_env :lastfm_archive, :interval, @interval
    File.rm_rf Path.join(@test_data_dir, "1")
  end

  @tag :disk_write
  test "archive scrobbles of a Lastfm user - archive/2", %{bypass: bypass} do
    # Bypass test only
    if(bypass) do
      user = "a_lastfm_user"
      prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
      test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "2"), user, prebaked_resp)
      capture_io(fn -> LastfmArchive.archive(user, 0) end)
    end
  after
    File.rm_rf Path.join(@test_data_dir, "2")
  end

end
