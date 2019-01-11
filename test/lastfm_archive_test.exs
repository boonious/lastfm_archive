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

    test "single year scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
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

    test "single day scrobbles of a Lastfm user, Date | archive/3", %{bypass: bypass} do
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

    test "today's scrobbles of a Lastfm user, :today | archive/3", %{bypass: bypass} do
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

    test "yesterday's (:yesterday) scrobbles of a Lastfm user, :yesterday | archive/3", %{bypass: bypass} do
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

    test "date range (multi-years) scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        date_range = Date.range(~D[2017-11-12], ~D[2018-04-01])
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "7"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

        archive_year_dir = Path.join [@test_data_dir, "7", user, "2017"]
        assert File.dir? archive_year_dir

        archive_year_dir = Path.join [@test_data_dir, "7", user, "2018"]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "7")
    end

    test "date range (single year) scrobbles of a Lastfm user, archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        date_range = Date.range(~D[2005-05-12], ~D[2005-12-01])
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "8"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

        archive_year_dir = Path.join [@test_data_dir, "8", user, "2005"]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "8")
    end

    test "date range (daily) scrobbles of a Lastfm user, Date.Range | archive/3", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        date_range = Date.range(~D[2018-05-30], ~D[2018-06-01])
        prebaked_resp = %{"info" => "./test/data/test_user2.json", "recenttracks" => "./test/data/test_recenttracks.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "9"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0, daily: true, overwrite: true) end)

        file_path = ~D[2018-05-30] |> Date.to_string |> String.split("-") |> Path.join
        archive_year_dir = Path.join [@test_data_dir, "9", user, file_path]
        assert File.dir? archive_year_dir

        file_path = ~D[2018-06-01] |> Date.to_string |> String.split("-") |> Path.join
        archive_year_dir = Path.join [@test_data_dir, "9", user, file_path]
        assert File.dir? archive_year_dir
      end
    after
      File.rm_rf Path.join(@test_data_dir, "9")
    end
  end

  describe "sync" do
    @describetag :disk_write

    test "scrobbles of the configured user - sync/0", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = Application.get_env(:lastfm_archive, :user)

        # speed up this test
        # no requirement for 'interval' beetween requests, since Bypass test is not hitting Lastfm API
        Application.put_env :lastfm_archive, :interval, 1

        prebaked_resp = %{"info" => "./test/data/test_user.json", "recenttracks" => "./test/data/test_recenttracks_no_scrobble.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "10"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.sync end)

        sync_log_file =  Path.join [@test_data_dir, "10", user, ".lastfm_archive"]
        assert File.exists? sync_log_file

        # re-sync, and from an older date from previous year
        File.write(sync_log_file, "sync_date=2017-12-25")
        capture_io(fn -> LastfmArchive.sync end)
      end
    after
      Application.put_env :lastfm_archive, :interval, @interval
      File.rm_rf Path.join(@test_data_dir, "10")
    end

    test "scrobbles of a Lastfm user - sync/1", %{bypass: bypass} do
      # Bypass test only
      if(bypass) do
        user = "a_lastfm_user"
        Application.put_env :lastfm_archive, :interval, 1

        prebaked_resp = %{"info" => "./test/data/test_user.json", "recenttracks" => "./test/data/test_recenttracks_no_scrobble.json"}
        test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "11"), user, prebaked_resp)
        capture_io(fn -> LastfmArchive.sync(user) end)

        sync_log_file =  Path.join [@test_data_dir, "11", user, ".lastfm_archive"]
        assert File.exists? sync_log_file

        File.write(sync_log_file, "sync_date=2018-12-25")
        capture_io(fn -> LastfmArchive.sync(user) end)
      end
    after
      Application.put_env :lastfm_archive, :interval, @interval
      File.rm_rf Path.join(@test_data_dir, "11")
    end

  end

  test "is_year guard" do
    assert LastfmArchive.is_year(2017)
    refute LastfmArchive.is_year(1234)
    refute LastfmArchive.is_year("2010")
  end

  test "tsv_file_header" do
    assert LastfmArchive.tsv_file_header == "id\tname\tscrobble_date\tscrobble_date_iso\tmbid\turl\tartist\tartist_mbid\tartist_url\talbum\talbum_mbid"
  end

end
