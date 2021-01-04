defmodule LoadTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @expected_solr_fields_path Path.join(["solr", "fields.json"])
  @test_data_dir Application.get_env(:lastfm_archive, :data_dir)

  setup do
    [bypass: Bypass.open()]
  end

  test "ping Solr endpoint by URL string)", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"

    Bypass.expect(bypass, fn conn ->
      assert conn.path_info == ["admin", "ping"]
      Plug.Conn.resp(conn, 200, "{}")
    end)

    LastfmArchive.Load.ping_solr(url)
  end

  test "ping Solr endpoint by URL config key", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Application.put_env(:hui, :lastfm_ping_test1, url: url)

    Bypass.expect(bypass, fn conn ->
      assert conn.path_info == ["admin", "ping"]
      Plug.Conn.resp(conn, 200, "{}")
    end)

    LastfmArchive.Load.ping_solr(:lastfm_ping_test1)
  end

  test "Solr schema check by URL string", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    expected_fields = File.read!(@expected_solr_fields_path) |> Jason.decode!()

    Bypass.expect(bypass, fn conn ->
      schema_response = File.read!(Path.join(["test", "data", "schema_response.json"]))
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end)

    {status, fields} = LastfmArchive.Load.check_solr_schema(url)

    assert status == :ok
    assert expected_fields == fields
  end

  test "Solr schema schema by URL config key", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Application.put_env(:hui, :lastfm_ping_test2, url: url)
    expected_fields = File.read!(@expected_solr_fields_path) |> Jason.decode!()

    Bypass.expect(bypass, fn conn ->
      schema_response = File.read!(Path.join(["test", "data", "schema_response.json"]))
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end)

    {status, fields} = LastfmArchive.Load.check_solr_schema(:lastfm_ping_test2)

    assert status == :ok
    assert expected_fields == fields
  end

  test "Solr schema check should returns error with malformed URL", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"
    Bypass.down(bypass)

    assert {:error, %Hui.Error{reason: :econnrefused}} = LastfmArchive.Load.check_solr_schema(url)
    assert {:error, %Hui.Error{reason: :ehostunreach}} = LastfmArchive.Load.check_solr_schema(:not_valid_url)
  end

  test "Solr schema check should returns error if fields are missing", %{bypass: bypass} do
    url = "http://localhost:#{bypass.port}/"

    Bypass.expect(bypass, fn conn ->
      schema_response = File.read!(Path.join(["test", "data", "schema_response_missing_fields.json"]))
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, schema_response)
    end)

    assert {:error, %Hui.Error{reason: :einit}} = LastfmArchive.Load.check_solr_schema(url)
  end

  test "read and parse TSV file into scrobble list from the archive, for a given user, file location" do
    test_user = "load_test_user"
    File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
    on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

    assert {:error, :enoent} = LastfmArchive.Load.read(test_user, "non_existing_file.tsv.gz")
    assert {:ok, [header | scrobbles]} = LastfmArchive.Load.read(test_user, "tsv/2018.tsv.gz")

    assert header == LastfmArchive.tsv_file_header()
    assert length(scrobbles) > 0
  end

  test "load a TSV file from the archive into Solr for a given user", %{bypass: bypass} do
    test_user = "load_test_user"
    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "#{bypass_url}", handler: "update", headers: headers}

    expected_solr_docs = File.read!(Path.join(["test", "data", "update_solr_docs1.json"]))

    File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
    on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert conn.method == "POST"
      assert body == expected_solr_docs

      Plug.Conn.resp(conn, 200, "{}")
    end)

    assert {:ok,
            %Hui.Http{
              body: "{}",
              headers: [
                {"cache-control", "max-age=0, private, must-revalidate"},
                {"date", _},
                {"server", "Cowboy"},
                {"content-length", "2"}
              ],
              method: :post,
              options: [],
              status: 200,
              url: _
            }} = LastfmArchive.Load.load_solr(url, test_user, "tsv/2018.tsv.gz")

    assert {:error, :enoent} = LastfmArchive.Load.load_solr(url, test_user, "not_available_file.tsv.gz")
  end

  test "load_archive/2: load all TSV data from the archive into Solr for a given user, via %Hui.URL{}", %{
    bypass: bypass
  } do
    test_user = "load_test_user"
    File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
    on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "#{bypass_url}", handler: "update", headers: headers}

    schema_response = File.read!(Path.join(["test", "data", "schema_response.json"]))
    expected_solr_docs = File.read!(Path.join(["test", "data", "update_solr_docs1.json"]))

    Bypass.expect(bypass, fn conn ->
      case conn.method do
        "GET" ->
          assert conn.path_info == ["schema"] or conn.path_info == ["admin", "ping"]

        "POST" ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          assert body == expected_solr_docs
      end

      Plug.Conn.resp(conn, 200, schema_response)
    end)

    capture_io(fn -> LastfmArchive.load_archive(test_user, url) end)
  end

  test "load_archive/2: load all TSV data from the archive into Solr for a given user, via URL config key", %{
    bypass: bypass
  } do
    test_user = "load_test_user"
    File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
    on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]

    Application.put_env(:hui, :test_url1, url: bypass_url, headers: headers, handler: "update")

    schema_response = File.read!(Path.join(["test", "data", "schema_response.json"]))

    Bypass.expect(bypass, fn conn ->
      if conn.method == "GET" do
        assert conn.path_info == ["schema"] or conn.path_info == ["admin", "ping"]
      end

      Plug.Conn.resp(conn, 200, schema_response)
    end)

    capture_io(fn -> LastfmArchive.load_archive(test_user, :test_url1) end)

    # test malformed URL
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, :not_valid_url_config_key)
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, nil)
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, "http://binary_url")
  end
end
