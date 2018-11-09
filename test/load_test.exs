defmodule LoadTest do
  use ExUnit.Case, async: true

  @expected_solr_fields_path Path.join ["solr", "fields.json"]

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

  test "ping Solr endpoint by URL config key", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Application.put_env :hui, :lastfm_ping_test1, url: url

    Bypass.expect bypass, fn conn ->
      assert conn.path_info == ["admin", "ping"]
      Plug.Conn.resp(conn, 200, "{}")
    end

    LastfmArchive.Load.ping_solr(:lastfm_ping_test1)
  end

  test "check Solr schema by URL string", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    expected_fields = File.read!(@expected_solr_fields_path) |> Poison.decode!

    Bypass.expect bypass, fn conn ->      
      schema_response = File.read!(Path.join ["test","data", "schema_response.json"])
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end

    {status, fields} = LastfmArchive.Load.check_solr_schema(url)

    assert status == :ok
    assert expected_fields == fields
  end

  test "check Solr schema by URL config key", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Application.put_env :hui, :lastfm_ping_test2, url: url
    expected_fields = File.read!(@expected_solr_fields_path) |> Poison.decode!

    Bypass.expect bypass, fn conn ->      
      schema_response = File.read!(Path.join ["test","data", "schema_response.json"])
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end

    {status, fields} = LastfmArchive.Load.check_solr_schema(:lastfm_ping_test2)

    assert status == :ok
    assert expected_fields == fields
  end

  test "should returns error if fields are missing in Solr schema check", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"

    Bypass.expect bypass, fn conn ->      
      schema_response = File.read!(Path.join ["test","data", "schema_response_missing_fields.json"])
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end

    assert {:error, %Hui.Error{reason: :einit} } = LastfmArchive.Load.check_solr_schema(url)
  end

end
