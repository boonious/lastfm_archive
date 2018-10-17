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

  @default_data_dir "./lastfm_data/"

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

  test "extract/0 requests params for the configured user", %{bypass: bypass} do
    if(bypass) do
      test_conn_params(bypass, @lastfm_tracks_api_params)
      LastfmArchive.extract
    else
      # if 'bypass' is nil, then integration testing with live Lastfm endpoint
      # required a valid Lastfm user in configuration 
      check_resp(LastfmArchive.extract)
    end
  end

  test "extract/1 requests params for a specific user", %{bypass: bypass} do
    # Bypass test only
    if(bypass) do
      test_conn_params(bypass, %{@lastfm_tracks_api_params | "user" => "a_lastfm_user"})
      LastfmArchive.extract("a_lastfm_user")
    end
  end

  test "write/2 compressed data to the default file location" do
    user = Application.get_env(:lastfm_archive, :user) || ""
    Application.put_env :lastfm_archive, :data_dir, @default_data_dir

    file_path = Path.join ["#{@default_data_dir}", "#{user}", "1.gz"]
    on_exit fn -> File.rm file_path end

    # use mocked data when available
    LastfmArchive.write("test")
    assert File.exists? file_path
    assert "test" == File.read!(file_path) |> :zlib.gunzip
  end

  test "write/2 compressed data to the configured file location" do
    user = Application.get_env(:lastfm_archive, :user) || ""
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir

    file_path = Path.join ["#{data_dir}", "#{user}", "1.gz"]
    on_exit fn -> File.rm file_path end

    # use mocked data when available
    LastfmArchive.write("test")
    assert File.exists? file_path
    assert "test" == File.read!(file_path) |> :zlib.gunzip
  end

  test "info/1 obtaining playcount and registered date for user", %{bypass: bypass} do
    if(bypass) do
      test_conn_params(bypass, @lastfm_info_api_params)
      LastfmArchive.info(Application.get_env(:lastfm_archive, :user))
    else
      # integration test
      check_resp(LastfmArchive.info(Application.get_env(:lastfm_archive, :user)))
    end
  end

  test "data_year_range/1 provide year ranges based on registered date" do
    {_, d0, _} = "2006-04-01T00:00:00Z" |> DateTime.from_iso8601
    {_, now, _} = "2018-04-01T00:00:00Z" |> DateTime.from_iso8601
    registered_date = d0 |> DateTime.to_unix
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
    assert LastfmArchive.data_year_range(registered_date, now) == expected_year_range
  end

  test "data_year_range/1 provide year range for a particular year (YYYY)" do
    year = "2012"
    expected_year_range = {1325376000, 1356998399}
    assert LastfmArchive.data_year_range(year) == expected_year_range

    year = "2005"
    expected_year_range = {1104537600, 1136073599}
    assert LastfmArchive.data_year_range(year) == expected_year_range
  end

end
