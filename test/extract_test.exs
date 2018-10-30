defmodule ExtractTest do
  use ExUnit.Case, async: true
  import TestHelpers

  doctest LastfmArchive

  @lastfm_tracks_api_params %{"method" => "user.getrecenttracks", 
                       "api_key" => Application.get_env(:elixirfm, :api_key), 
                       "user" => Application.get_env(:lastfm_archive, :user), "limit" => "1", "extended" => "1", "page" => "1"}

  @lastfm_info_api_params %{"method" => "user.getinfo",
                       "api_key" => Application.get_env(:elixirfm, :api_key), 
                       "user" => Application.get_env(:lastfm_archive, :user)}

  @test_data_dir Path.join([".", "lastfm_data", "test", "extract"])

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

  test "extract/5 requests params for a specific user", %{bypass: bypass} do
    if(bypass) do
      # Bypass test
      test_bypass_conn_params(bypass, %{@lastfm_tracks_api_params | "user" => "a_lastfm_user"})
      LastfmArchive.Extract.extract("a_lastfm_user")
    else
      # integration test, require a user with 2012 scrobbles
      user = Application.get_env(:lastfm_archive, :user)
      api_key = Application.get_env(:elixirfm, :api_key)
      {_status, resp} = LastfmArchive.Extract.extract(user, 1, 5, 1325376000, 1356998399) # 2012 scrobbles
      resp_body = resp.body |> Poison.decode!

      track = resp_body["recenttracks"]["track"] |> hd
      track_date_uts = track["date"]["uts"] |> String.to_integer
      track_date = DateTime.from_unix!(track_date_uts)

      assert track_date.year == 2012
      assert length(resp_body["recenttracks"]["track"]) == 5
      assert String.match? resp.request_url, ~r/#{user}/
      assert String.match? resp.request_url, ~r/#{api_key}/
    end
  end

  describe "data output" do
    @describetag :disk_write

    test "write/3 compressed data to the default file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env :lastfm_archive, :data_dir, @test_data_dir

      file_path = Path.join ["#{@test_data_dir}", "#{user}", "1.gz"]
      on_exit fn -> File.rm file_path end

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test")
      assert File.exists? file_path
      assert "test" == File.read!(file_path) |> :zlib.gunzip
    end

    test "write/3 compressed data to the configured file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env :lastfm_archive, :data_dir, @test_data_dir

      data_dir = Application.get_env(:lastfm_archive, :data_dir)
      file_path = Path.join ["#{data_dir}", "#{user}", "1.gz"]
      on_exit fn -> File.rm file_path end

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test")
      assert File.exists? file_path
      assert "test" == File.read!(file_path) |> :zlib.gunzip
    end

    test "write/2 compressed data to nested file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env :lastfm_archive, :data_dir, @test_data_dir

      data_dir = Application.get_env(:lastfm_archive, :data_dir)
      file_path = Path.join ["#{data_dir}", "#{user}", "2007/02/1.gz"]
      on_exit fn -> File.rm file_path end

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test", "2007/02/1")
      assert File.exists? file_path
      assert "test" == File.read!(file_path) |> :zlib.gunzip
    end
  end

  test "info/1 playcount and registered date for a user", %{bypass: bypass} do
    if(bypass) do
      test_bypass_conn_params(bypass, @lastfm_info_api_params)
      LastfmArchive.Extract.info(Application.get_env(:lastfm_archive, :user))
    else
      # integration test
      check_resp(LastfmArchive.Extract.info(Application.get_env(:lastfm_archive, :user)))
    end
  end

  test "info/2 playcount in a particular year for a user", %{bypass: bypass} do
    if(bypass) do
     test_year_range = {1167609600, 1199145599} #2007
     expected_params = %{"method" => "user.getrecenttracks",
                         "api_key" => Application.get_env(:elixirfm, :api_key),
                         "user" => Application.get_env(:lastfm_archive, :user),
                         "limit" => "1", "page" => "1",
                         "from" => "1167609600", "to" => "1199145599"}

      test_bypass_conn_params(bypass, expected_params)
      LastfmArchive.Extract.info(Application.get_env(:lastfm_archive, :user), test_year_range)
    end
  end

  test "time_range/1 provide year time ranges based on registered date" do
    {_, d0, _} = "2006-04-01T00:00:00Z" |> DateTime.from_iso8601
    {_, d1, _} = "2018-04-01T00:00:00Z" |> DateTime.from_iso8601
    registered_date = d0 |> DateTime.to_unix
    now = d1 |> DateTime.to_unix
    expected_year_range = [
     {1136073600, 1167609599},
     {1167609600, 1199145599},
     {1199145600, 1230767999},
     {1230768000, 1262303999},
     {1262304000, 1293839999},
     {1293840000, 1325375999},
     {1325376000, 1356998399},
     {1356998400, 1388534399},
     {1388534400, 1420070399},
     {1420070400, 1451606399},
     {1451606400, 1483228799},
     {1483228800, 1514764799},
     {1514764800, 1546300799}
    ]
    assert LastfmArchive.time_range(registered_date, now) == expected_year_range
  end

  test "time_range/1 provide year time range for a particular year (YYYY)" do
    year = "2012"
    expected_year_range = {1325376000, 1356998399}
    assert LastfmArchive.time_range(year) == expected_year_range

    year = "2005"
    expected_year_range = {1104537600, 1136073599}
    assert LastfmArchive.time_range(year) == expected_year_range
  end

end
