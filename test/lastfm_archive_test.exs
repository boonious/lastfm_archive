defmodule LastfmArchiveTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mox

  doctest LastfmArchive

  @test_data_dir Application.get_env(:lastfm_archive, :data_dir)

  setup_all do
    defmock(Lastfm.ClientMock, for: Lastfm.Client)
    :ok
  end

  describe "archive all scrobbles" do
    @describetag :disk_write

    test "of the configured user - archive/0" do
      user = Application.get_env(:lastfm_archive, :user)

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {1234, 1_472_601_600} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> 12 end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      capture_io(fn -> LastfmArchive.archive() end)
    end

    test "of a given Lastfm user - archive/2" do
      user = "a_lastfm_user"

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {12, DateTime.utc_now() |> DateTime.to_unix()} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> 0 end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      capture_io(fn -> LastfmArchive.archive(user, interval: 0) end)
    after
      File.rm_rf(Path.join(@test_data_dir, "a_lastfm_user"))
    end
  end

  describe "archive/3 scrobbles of a Lastfm user given a time frame:" do
    setup do
      user = Application.get_env(:lastfm_archive, :user)

      Lastfm.ClientMock
      |> stub(:playcount, fn ^user, _time_range, _api -> 12 end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      on_exit(fn ->
        File.rm_rf(Path.join(@test_data_dir, user))
      end)

      %{user: user}
    end

    test "single year", %{user: user} do
      archive_year = 2015
      archive_dir = Path.join([@test_data_dir, user, archive_year |> to_string])

      capture_io(fn -> LastfmArchive.archive(user, archive_year, interval: 0) end)
      assert File.dir?(archive_dir)
    end

    test "single day", %{user: user} do
      archive_day = ~D[2012-12-12]
      file_path = archive_day |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])

      capture_io(fn -> LastfmArchive.archive(user, archive_day, interval: 0) end)
      assert File.dir?(archive_dir)
    end

    test "today", %{user: user} do
      date_range = :today
      file_path = Date.utc_today() |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])

      capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)
      assert File.dir?(archive_dir)
    end

    test "yesterday", %{user: user} do
      date_range = :yesterday
      file_path = Date.utc_today() |> Date.add(-1) |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])

      capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)
      assert File.dir?(archive_dir)
    end

    test "multi-years date range", %{user: user} do
      date_range = Date.range(~D[2017-11-12], ~D[2018-04-01])
      capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

      archive_dir = Path.join([@test_data_dir, user, "2017"])
      assert File.dir?(archive_dir)

      archive_dir = Path.join([@test_data_dir, user, "2018"])
      assert File.dir?(archive_dir)
    end

    test "date range within a single year", %{user: user} do
      date_range = Date.range(~D[2005-05-12], ~D[2005-12-01])

      capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0) end)

      archive_dir = Path.join([@test_data_dir, user, "2005"])
      assert File.dir?(archive_dir)
    end

    test "date range in daily granularity", %{user: user} do
      date_range = Date.range(~D[2018-05-30], ~D[2018-06-01])
      capture_io(fn -> LastfmArchive.archive(user, date_range, interval: 0, daily: true, overwrite: true) end)

      file_path = ~D[2018-05-30] |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])
      assert File.dir?(archive_dir)

      file_path = ~D[2018-05-31] |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])
      assert File.dir?(archive_dir)

      file_path = ~D[2018-06-01] |> Date.to_string() |> String.split("-") |> Path.join()
      archive_dir = Path.join([@test_data_dir, user, file_path])
      assert File.dir?(archive_dir)
    end
  end

  describe "sync" do
    @describetag :disk_write

    test "scrobbles of the configured user - sync/0" do
      user = Application.get_env(:lastfm_archive, :user)

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {1234, 1_472_601_600} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> 0 end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      capture_io(fn -> LastfmArchive.sync() end)

      sync_log_file = Path.join([@test_data_dir, user, ".lastfm_archive"])
      assert File.exists?(sync_log_file)

      today = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()
      assert File.read!(sync_log_file) |> String.contains?(today)
    after
      File.rm_rf(Path.join(@test_data_dir, Application.get_env(:lastfm_archive, :user)))
    end

    test "scrobbles of a Lastfm user - sync/1" do
      user = "a_lastfm_user"

      Lastfm.ClientMock
      |> expect(:info, fn ^user, _api -> {1234, 1_578_068_137} end)
      |> stub(:playcount, fn ^user, _time_range, _api -> 12 end)
      |> stub(:scrobbles, fn ^user, _params, _api -> %{} end)

      capture_io(fn -> LastfmArchive.sync(user) end)

      sync_log_file = Path.join([@test_data_dir, user, ".lastfm_archive"])
      assert File.exists?(sync_log_file)

      File.write(sync_log_file, "sync_date=2020-12-25")
      capture_io(fn -> LastfmArchive.sync(user) end)

      today = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()
      assert File.read!(sync_log_file) |> String.contains?(today)
    after
      File.rm_rf(Path.join(@test_data_dir, "a_lastfm_user"))
    end
  end

  test "is_year guard" do
    assert LastfmArchive.is_year(2017)
    refute LastfmArchive.is_year(1234)
    refute LastfmArchive.is_year("2010")
  end

  test "tsv_file_header" do
    assert LastfmArchive.tsv_file_header() ==
             "id\tname\tscrobble_date\tscrobble_date_iso\tmbid\turl\tartist\tartist_mbid\tartist_url\talbum\talbum_mbid"
  end
end
