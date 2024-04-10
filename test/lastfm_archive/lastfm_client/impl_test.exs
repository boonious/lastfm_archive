defmodule LastfmArchive.LastfmClient.ImplTest do
  use ExUnit.Case, async: true

  import LastfmArchive.Factory, only: [build: 2]

  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi

  setup_all do
    %{user: "lastfm_client_test_user"}
  end

  describe "scrobbles/3" do
    setup context do
      bypass = Bypass.open()
      count = 100
      tracks = build(:recent_tracks, user: context.user, total: count, num_of_plays: 3) |> Jason.encode!()

      %{
        bypass: bypass,
        count: count,
        api: %LastfmApi{
          key: "12345",
          endpoint: "http://localhost:#{bypass.port}/",
          method: "user.getrecenttracks"
        },
        params: {1, 1, 1_167_609_600, 1_199_145_599},
        tracks: tracks
      }
    end

    test "returns scrobbles of a user for given a time range", %{
      api: api,
      bypass: bypass,
      count: count,
      params: params,
      tracks: tracks,
      user: user
    } do
      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)

        assert %{
                 "user" => ^user,
                 "from" => "1167609600",
                 "to" => "1199145599",
                 "page" => "1",
                 "limit" => "1"
               } = params

        Plug.Conn.resp(conn, 200, tracks)
      end)

      assert {:ok, %{"recenttracks" => resp}} = LastfmClient.scrobbles(user, params, api)
      assert %{"@attr" => attr, "track" => tracks} = resp

      assert %{"user" => ^user, "total" => ^count} = attr
      assert tracks |> length() == 3
    end

    test "authentication and endpoint params", %{
      api: api,
      bypass: bypass,
      params: params,
      tracks: tracks,
      user: user
    } do
      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)
        assert "Bearer #{api.key}" == authorization_header
        assert %{"api_key" => "12345", "method" => "user.getrecenttracks"} = params

        Plug.Conn.resp(conn, 200, tracks)
      end)

      assert {:ok, %{"recenttracks" => %{}}} = LastfmClient.scrobbles(user, params, api)
    end

    test "paging and limit params", %{
      api: api,
      bypass: bypass,
      params: {_page, _limit, from, to},
      tracks: tracks,
      user: user
    } do
      page = 2
      limit = 50
      params = {page, limit, from, to}

      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        assert %{"page" => "2", "limit" => "50"} = params
        Plug.Conn.resp(conn, 200, tracks)
      end)

      assert {:ok, %{"recenttracks" => %{}}} = LastfmClient.scrobbles(user, params, api)
    end

    test "returns error tuple on API error response", %{bypass: bypass, api: api, params: params, user: user} do
      message = "Invalid Method - No method with that name in this package"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, "{\"error\":3,\"message\":\"#{message}\"}")
      end)

      assert {:error, message} == LastfmClient.scrobbles(user, params, api)
    end

    test "return error tuple when Lastfm API is down", %{bypass: bypass, api: api, params: params, user: user} do
      Bypass.down(bypass)
      assert {:error, {:failed_connect, _message}} = LastfmClient.scrobbles(user, params, api)
    end
  end

  describe "info/2" do
    setup context do
      bypass = Bypass.open()

      %{
        bypass: bypass,
        api: %LastfmApi{
          user: context.user,
          key: "12345",
          endpoint: "http://localhost:#{bypass.port}/",
          method: "user.getinfo"
        }
      }
    end

    test "returns count and registered date for a user", %{bypass: bypass, api: api, user: user} do
      registered_time = 1_472_601_600
      playcount = 1234
      user_info = build(:user_info, user: user, playcount: playcount, registered_time: registered_time)

      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.key}" == authorization_header
        assert %{"api_key" => "12345", "method" => "user.getinfo", "user" => ^user} = params

        Plug.Conn.resp(conn, 200, user_info |> Jason.encode!())
      end)

      assert {:ok, {1234, 1_472_601_600}} == LastfmClient.info(user, api)
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

    test "returns count and last scrobble data of a user given a time range", %{
      api: api,
      bypass: bypass,
      time_range: time_range,
      user: user
    } do
      count = 120
      tracks = build(:recent_tracks, user: user, total: count, num_of_plays: 1)
      last_scobble_time = hd(tracks["recenttracks"]["track"])["date"]["uts"] |> String.to_integer()

      Bypass.expect(bypass, fn conn ->
        params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
        authorization_header = conn.req_headers |> Enum.find(&(elem(&1, 0) == "authorization")) |> elem(1)

        assert "Bearer #{api.key}" == authorization_header

        assert %{
                 "api_key" => "12345",
                 "method" => "user.getrecenttracks",
                 "user" => ^user,
                 "from" => "1167609600",
                 "to" => "1199145599"
               } = params

        Plug.Conn.resp(conn, 200, tracks |> Jason.encode!())
      end)

      assert {:ok, {^count, ^last_scobble_time}} = LastfmClient.playcount(user, time_range, api)
    end

    test "returns 0 count and nil last scrobble time when playcount is 0", %{user: user} = context do
      tracks = build(:recent_tracks, user: user, total: 0, num_of_plays: 0)

      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, tracks |> Jason.encode!())
      end)

      assert {:ok, {0, nil}} = LastfmClient.playcount(user, context.time_range, context.api)
    end

    test "returns 0 count and nil last scrobble time on `now_playing` track", %{user: user} = context do
      tracks = build(:recent_tracks, user: user, total: 0, num_of_plays: 1, nowplaying: true) |> Jason.encode!()

      Bypass.expect(context.bypass, fn conn ->
        Plug.Conn.resp(conn, 200, tracks)
      end)

      assert {:ok, {0, nil}} = LastfmClient.playcount(user, context.time_range, context.api)
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
