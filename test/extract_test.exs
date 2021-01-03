defmodule ExtractTest do
  use ExUnit.Case, async: true
  import TestHelpers

  doctest LastfmArchive

  @lastfm_tracks_api_params %{
    "method" => "user.getrecenttracks",
    "api_key" => Application.get_env(:elixirfm, :api_key),
    "user" => Application.get_env(:lastfm_archive, :user),
    "limit" => "1",
    "extended" => "1",
    "page" => "1"
  }

  @test_data_dir Path.join([".", "lastfm_data", "test", "extract"])

  # testing with Bypass
  setup do
    lastfm_ws = Application.get_env(:elixirfm, :lastfm_ws)
    configured_dir = Application.get_env(:lastfm_archive, :data_dir)

    # true if mix test --include integration 
    is_integration = :integration in ExUnit.configuration()[:include]
    bypass = unless is_integration, do: Bypass.open(), else: nil

    on_exit(fn ->
      Application.put_env(:elixirfm, :lastfm_ws, lastfm_ws)
      Application.put_env(:lastfm_archive, :data_dir, configured_dir)
    end)

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
      # 2012 scrobbles
      {_status, resp} = LastfmArchive.Extract.extract(user, 1, 5, 1_325_376_000, 1_356_998_399)
      resp_body = resp.body |> Jason.decode!()

      track = resp_body["recenttracks"]["track"] |> hd
      track_date_uts = track["date"]["uts"] |> String.to_integer()
      track_date = DateTime.from_unix!(track_date_uts)

      assert track_date.year == 2012
      assert length(resp_body["recenttracks"]["track"]) == 5
      assert String.match?(resp.request_url, ~r/#{user}/)
      assert String.match?(resp.request_url, ~r/#{api_key}/)
    end
  end

  describe "data output" do
    @describetag :disk_write

    test "write/3 compressed data to the default file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env(:lastfm_archive, :data_dir, @test_data_dir)

      file_path = Path.join(["#{@test_data_dir}", "#{user}", "1.gz"])
      on_exit(fn -> File.rm(file_path) end)

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test")
      assert File.exists?(file_path)
      assert "test" == File.read!(file_path) |> :zlib.gunzip()
    end

    test "write/3 compressed data to the configured file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env(:lastfm_archive, :data_dir, @test_data_dir)

      data_dir = Application.get_env(:lastfm_archive, :data_dir)
      file_path = Path.join(["#{data_dir}", "#{user}", "1.gz"])
      on_exit(fn -> File.rm(file_path) end)

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test")
      assert File.exists?(file_path)
      assert "test" == File.read!(file_path) |> :zlib.gunzip()
    end

    test "write/2 compressed data to nested file location" do
      user = Application.get_env(:lastfm_archive, :user) || ""
      Application.put_env(:lastfm_archive, :data_dir, @test_data_dir)

      data_dir = Application.get_env(:lastfm_archive, :data_dir)
      file_path = Path.join(["#{data_dir}", "#{user}", "2007/02/1.gz"])
      on_exit(fn -> File.rm(file_path) end)

      # use mocked data when available
      LastfmArchive.Extract.write(user, "test", "2007/02/1")
      assert File.exists?(file_path)
      assert "test" == File.read!(file_path) |> :zlib.gunzip()
    end
  end

  test "time_range/1 provide year time ranges based on registered date" do
    {_, d0, _} = "2006-04-01T00:00:00Z" |> DateTime.from_iso8601()
    {_, d1, _} = "2018-04-01T00:00:00Z" |> DateTime.from_iso8601()
    registered_date = d0 |> DateTime.to_unix()
    now = d1 |> DateTime.to_unix()

    expected_year_range = [
      {1_136_073_600, 1_167_609_599},
      {1_167_609_600, 1_199_145_599},
      {1_199_145_600, 1_230_767_999},
      {1_230_768_000, 1_262_303_999},
      {1_262_304_000, 1_293_839_999},
      {1_293_840_000, 1_325_375_999},
      {1_325_376_000, 1_356_998_399},
      {1_356_998_400, 1_388_534_399},
      {1_388_534_400, 1_420_070_399},
      {1_420_070_400, 1_451_606_399},
      {1_451_606_400, 1_483_228_799},
      {1_483_228_800, 1_514_764_799},
      {1_514_764_800, 1_546_300_799}
    ]

    assert LastfmArchive.time_range(registered_date, now) == expected_year_range
  end

  test "time_range/1 provide year time range for a particular year (YYYY)" do
    year = "2012"
    expected_year_range = {1_325_376_000, 1_356_998_399}
    assert LastfmArchive.time_range(year) == expected_year_range

    year = "2005"
    expected_year_range = {1_104_537_600, 1_136_073_599}
    assert LastfmArchive.time_range(year) == expected_year_range
  end
end
