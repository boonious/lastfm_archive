defmodule LastfmArchive.LastfmClient.ImplTest do
  use ExUnit.Case, async: true

  import Fixtures.Lastfm,
    only: [
      recent_tracks: 2,
      recent_tracks: 3,
      recent_tracks_zero_count: 0,
      recent_tracks_zero_count_now_playing: 0,
      user_info: 3
    ]

  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi

  describe "scrobbles/3" do
    setup do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %LastfmApi{
          key: "12345",
          endpoint: "http://localhost:#{bypass.port}/",
          method: "user.getrecenttracks"
        },
        params: {1, 1, 1_167_609_600, 1_199_145_599}
      }
    end

    test "returns scrobbles of a user for given a time range", %{bypass: bypass, api: api, params: params} do
      {user, count} = {"a_lastfm_user", 12}

      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.key}" == authorization_header

        assert %{
                 "api_key" => "12345",
                 "method" => "user.getrecenttracks",
                 "user" => "a_lastfm_user",
                 "from" => "1167609600",
                 "to" => "1199145599",
                 "page" => "1",
                 "limit" => "1"
               } = params

        Plug.Conn.resp(conn, 200, recent_tracks(user, count))
      end)

      assert {:ok, %{"recenttracks" => %{"@attr" => %{"user" => ^user, "total" => ^count}}}} =
               LastfmClient.scrobbles("a_lastfm_user", params, api)
    end

    test "returns error tuple on API error response", %{bypass: bypass, api: api, params: params} do
      message = "Invalid Method - No method with that name in this package"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{message}\"}")
      end)

      assert {:error, message} == LastfmClient.scrobbles("a_lastfm_user", params, api)
    end

    test "return error tuple when Lastfm API is down", %{bypass: bypass, api: api, params: params} do
      Bypass.down(bypass)
      assert {:error, {:failed_connect, _message}} = LastfmClient.scrobbles("a_lastfm_user", params, api)
    end
  end

  describe "info/2" do
    setup do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %LastfmApi{key: "12345", endpoint: "http://localhost:#{bypass.port}/", method: "user.getinfo"}
      }
    end

    test "returns count and registered date for a user", %{bypass: bypass, api: api} do
      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.key}" == authorization_header
        assert %{"api_key" => "12345", "method" => "user.getinfo", "user" => "a_lastfm_user"} = params

        Plug.Conn.resp(conn, 200, user_info("a_lastfm_user", 1234, 1_472_601_600))
      end)

      assert {:ok, {1234, 1_472_601_600}} == LastfmClient.info("a_lastfm_user", api)
    end

    test "returns error tuple on API error response", %{bypass: bypass, api: api} do
      message = "Invalid Method - No method with that name in this package"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{message}\"}")
      end)

      assert {:error, message} == LastfmClient.info("a_lastfm_user", api)
    end

    test "returns error tuple when Lastfm API is down", %{bypass: bypass, api: api} do
      Bypass.down(bypass)
      assert {:error, {:failed_connect, _message}} = LastfmClient.info("a_lastfm_user", api)
    end
  end

  describe "playcount/3" do
    setup do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %LastfmApi{
          key: "12345",
          endpoint: "http://localhost:#{bypass.port}/",
          method: "user.getrecenttracks"
        },
        time_range: {1_167_609_600, 1_199_145_599}
      }
    end

    test "returns count and last scrobble data of a user given a time range", context do
      count = 12
      last_scobble_time = 1_618_328_464

      Bypass.expect(context.bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{context.api.key}" == authorization_header

        assert %{
                 "api_key" => "12345",
                 "method" => "user.getrecenttracks",
                 "user" => "a_lastfm_user",
                 "from" => "1167609600",
                 "to" => "1199145599"
               } = params

        Plug.Conn.resp(conn, 200, recent_tracks("a_lastfm_user", count, last_scobble_time))
      end)

      assert {:ok, {^count, ^last_scobble_time}} =
               LastfmClient.playcount("a_lastfm_user", context.time_range, context.api)
    end

    test "returns 0 count and nil last scrobble time when playcount is 0", context do
      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, recent_tracks_zero_count())
      end)

      assert {:ok, {0, nil}} = LastfmClient.playcount("a_lastfm_user", context.time_range, context.api)
    end

    test "returns 0 count and nil last scrobble time when Lastfm returns `now_playing` track", context do
      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, recent_tracks_zero_count_now_playing())
      end)

      assert {:ok, {0, nil}} = LastfmClient.playcount("a_lastfm_user", context.time_range, context.api)
    end

    test "returns error tuple on API error response", context do
      message = "Invalid Method - No method with that name in this package"

      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{message}\"}")
      end)

      assert {:error, message} == LastfmClient.playcount("a_lastfm_user", context.time_range, context.api)
    end

    test "returns error tuple when Lastfm API is down", %{bypass: bypass, api: api, time_range: time_range} do
      Bypass.down(bypass)
      assert {:error, {:failed_connect, _message}} = LastfmClient.playcount("a_lastfm_user", time_range, api)
    end
  end
end
