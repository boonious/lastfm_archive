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

  describe "archive" do
    @describetag :disk_write

    test "scrobbles of the configured user - archive/0", %{bypass: bypass} do
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

        no_scrobble_log_file = Path.join [@test_data_dir, "1", user, ".no_scrobble"]
        assert File.exists? no_scrobble_log_file
      end
    after
      Application.put_env :lastfm_archive, :interval, @interval
      File.rm_rf Path.join(@test_data_dir, "1")
    end

    test "scrobbles of a Lastfm user - archive/2", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "2"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, interval: 0) end)
      end
    after
      File.rm_rf Path.join(@test_data_dir, "2")
    end

    test "specific year scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        archive_year = 2015
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "3"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, archive_year, interval: 0) end)

        archive_year_dir = Path.join [@test_data_dir, "3", user, archive_year |> to_string]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "3")
    end

    test "specific day scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        archive_day = ~D[2012-12-12]
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "4"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, archive_day, interval: 0) end)

        file_path = archive_day |> Date.to_string |> String.split("-") |> Path.join
        archive_year_dir = Path.join [@test_data_dir, "4", user, file_path]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "4")
    end

    test "today's scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        date_range = :today
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "5"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

        file_path = Date.utc_today |> Date.to_string |> String.split("-") |> Path.join
        archive_year_dir = Path.join [@test_data_dir, "5", user, file_path]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "5")
    end

    test "yesterday's scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        date_range = :yesterday
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "6"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

        file_path = Date.utc_today |> Date.add(-1) |> Date.to_string |> String.split("-") |> Path.join
        archive_year_dir = Path.join [@test_data_dir, "6", user, file_path]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "6")
    end

  end

  test "is_year guard" do
    assert LastfmArchive.is_year(2017)
    refute LastfmArchive.is_year(1234)
    refute LastfmArchive.is_year("2010")
  end

end
