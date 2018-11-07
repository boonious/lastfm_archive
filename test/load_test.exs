defmodule LoadTest do
  use ExUnit.Case, async: true

  setup do
    # true if mix test --include integration 
    is_integration = :integration in ExUnit.configuration[:include]
    bypass = unless is_integration, do: Bypass.open, else: nil

    [bypass: bypass]
  end

  test "ping Solr endpoint by URL string)", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"

    Bypass.expect bypass, fn conn ->
      assert conn.path_info == ["admin", "ping"]
      Plug.Conn.resp(conn, 200, "{}")
    end

    LastfmArchive.Load.ping_solr(url)
  end

  test "ping Solr endpoint by config atom key", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Application.put_env :hui, :lastfm_ping_test, url: url

    Bypass.expect bypass, fn conn ->
      assert conn.path_info == ["admin", "ping"]
      Plug.Conn.resp(conn, 200, "{}")
    end

    LastfmArchive.Load.ping_solr(:lastfm_ping_test)
  end

end
