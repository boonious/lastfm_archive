ExUnit.start()

defmodule TestHelpers do
  import ExUnit.Assertions

  def test_bypass_conn_params(bypass, expected_params, prebaked_resp \\ "{}") do
    test_ws = "http://localhost:#{bypass.port}/"
    Application.put_env(:elixirfm, :lastfm_ws, test_ws)

    Bypass.expect(bypass, fn conn ->
      params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
      param_keys = params |> Map.keys()

      for {k, v} <- expected_params do
        assert k in param_keys
        assert v == params[k]
      end

      Plug.Conn.resp(conn, 200, prebaked_resp)
    end)
  end

  def test_bypass_conn_params_archive(bypass, test_dir, user, prebaked_resp) do
    api_key = Application.get_env(:elixirfm, :api_key)
    prebaked_resp_get_info = File.read!(prebaked_resp["info"])
    prebaked_resp_get_recenttraacks = File.read!(prebaked_resp["recenttracks"])

    test_ws = "http://localhost:#{bypass.port}/"
    Application.put_env(:elixirfm, :lastfm_ws, test_ws)
    Application.put_env(:lastfm_archive, :data_dir, test_dir)

    Bypass.expect(bypass, fn conn ->
      params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
      param_keys = params |> Map.keys()

      expected_params =
        if String.match?(conn.query_string, ~r/getrecenttracks/) do
          %{
            "method" => "user.getrecenttracks",
            "api_key" => api_key,
            "user" => user,
            "to" => "\\\d*",
            "from" => "\\\d*"
          }
        else
          %{"method" => "user.getinfo", "api_key" => api_key, "user" => user}
        end

      for {k, v} <- expected_params do
        assert k in param_keys
        assert String.match?(params[k], Regex.compile!(v))
      end

      if String.match?(conn.query_string, ~r/getrecenttracks/) do
        Plug.Conn.resp(conn, 200, prebaked_resp_get_recenttraacks)
      else
        Plug.Conn.resp(conn, 200, prebaked_resp_get_info)
      end
    end)
  end

  def check_resp({_status, %{"error" => _, "links" => _, "message" => message}}) do
    assert message != "User not found"
  end

  def check_resp({:ok, %{"recenttracks" => %{"@attr" => info, "track" => tracks}}}) do
    assert length(tracks) > 0
    assert info["total"] > 0
    assert info["user"] == Application.get_env(:lastfm_archive, :user)
  end

  def check_resp({playcount, registered}) do
    assert playcount > 0
    assert registered > 0
  end
end
