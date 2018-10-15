ExUnit.start()

defmodule TestHelpers do
  import ExUnit.Assertions

  def test_conn_params(bypass, expected_params) do
    test_ws = "http://localhost:#{bypass.port}/"
    Application.put_env :elixirfm, :lastfm_ws, test_ws

    Bypass.expect bypass, fn conn ->
      params = Plug.Conn.fetch_query_params(conn) |> Map.fetch!(:query_params)
      param_keys = params |> Map.keys
      for {k,v} <- expected_params do
        assert k in param_keys
        assert v == params[k]
      end

      Plug.Conn.resp(conn, 200, "{}")
    end
  end

  def check_resp({_status, %{"error" => _, "links" => _, "message" => message}}) do
    assert message != "User not found"
  end

  def check_resp({:ok, %{"recenttracks" => %{"@attr" => info, "track" => tracks} }}) do
    assert length(tracks) > 0
    assert info["total"] > 0
    assert info["user"] == Application.get_env(:lastfm_archive, :user)
  end

  def check_resp({playcount, registered}) do
    assert playcount > 0
    assert registered > 0
  end

end