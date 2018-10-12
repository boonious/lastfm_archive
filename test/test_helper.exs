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

end