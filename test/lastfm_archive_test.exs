defmodule LastfmArchiveTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  doctest LastfmArchive

  @test_data_dir Path.join([".", "lastfm_data", "test"])

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

  test "archive user", %{bypass: bypass} do
    if(bypass) do
      user = Application.get_env(:lastfm_archive, :user)
      api_key = Application.get_env(:elixirfm, :api_key)
      prebaked_resp_get_info = File.read!("./test/data/test_user.json")
      prebaked_resp_get_recenttraacks = File.read!("./test/data/test_recenttracks.json")

      test_ws = "http://localhost:#{bypass.port}/"
      Application.put_env :elixirfm, :lastfm_ws, test_ws
      Application.put_env :lastfm_archive, :data_dir, @test_data_dir

      Bypass.expect bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        param_keys = params |> Map.keys
        expected_params = if String.match?(conn.query_string, ~r/getrecenttracks/) do
          %{"method" => "user.getrecenttracks", "api_key" => api_key, "user" => user, "to" => "\\\d*", "from" => "\\\d*"}
        else
          %{"method" => "user.getinfo", "api_key" => api_key, "user" => user}
        end

        for {k,v} <- expected_params do
          assert k in param_keys
          assert String.match? params[k], Regex.compile!(v)
        end

        if String.match?(conn.query_string, ~r/getrecenttracks/) do
          Plug.Conn.resp(conn, 200, prebaked_resp_get_recenttraacks)
        else
          Plug.Conn.resp(conn, 200, prebaked_resp_get_info)
        end
      end

      capture_io(fn -> LastfmArchive.archive(user,0) end)
    end
  end

end
