defmodule Lastfm.ExtractTest do
  use ExUnit.Case, async: true

  import Fixtures.Lastfm
  alias Lastfm.{Client, Extract}

  describe "info/2" do
    setup do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %Client{api_key: "12345", endpoint: "http://localhost:#{bypass.port}/", method: "user.getinfo"}
      }
    end

    test "returns count and registered date for a user", %{bypass: bypass, api: api} do
      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.api_key}" == authorization_header
        assert %{"api_key" => "12345", "method" => "user.getinfo", "user" => "a_lastfm_user"} = params

        Plug.Conn.resp(conn, 200, user_info("a_lastfm_user", 1234, 1_472_601_600))
      end)

      Extract.info("a_lastfm_user", api)
    end

    test "raises exception when API returns error", %{bypass: bypass, api: api} do
      error_message = "Invalid Method - No method with that name in this package"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{error_message}\"}")
      end)

      assert_raise RuntimeError, error_message, fn ->
        Extract.info("a_lastfm_user", api)
      end
    end

    test "raises exception when Lastfm API is down", %{bypass: bypass, api: api} do
      Bypass.down(bypass)

      assert_raise RuntimeError, "failed to connect with Lastfm API", fn ->
        Extract.info("a_lastfm_user", api)
      end
    end
  end

  describe "playcount/2" do
    setup do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %Client{api_key: "12345", endpoint: "http://localhost:#{bypass.port}/", method: "user.getrecenttracks"},
        time_range: {1_167_609_600, 1_199_145_599}
      }
    end

    test "returns count of a user given a time range", %{bypass: bypass, api: api, time_range: time_range} do
      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.api_key}" == authorization_header

        assert %{
                 "api_key" => "12345",
                 "method" => "user.getrecenttracks",
                 "user" => "a_lastfm_user",
                 "from" => "1167609600",
                 "to" => "1199145599"
               } = params

        Plug.Conn.resp(conn, 200, recent_tracks("a_lastfm_user", "12"))
      end)

      Extract.playcount("a_lastfm_user", time_range, api)
    end

    test "playcount/2 raises exception when API returns error", context do
      error_message = "Invalid Method - No method with that name in this package"

      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{error_message}\"}")
      end)

      assert_raise RuntimeError, error_message, fn ->
        Extract.playcount("a_lastfm_user", context.time_range, context.api)
      end
    end

    test "raises exception when Lastfm API is down", %{bypass: bypass, api: api, time_range: time_range} do
      Bypass.down(bypass)

      assert_raise RuntimeError, "failed to connect with Lastfm API", fn ->
        Extract.playcount("a_lastfm_user", time_range, api)
      end
    end
  end
end
