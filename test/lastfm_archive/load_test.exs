defmodule LastfmArchive.LoadTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Mox
  import Fixtures.Archive

  alias LastfmArchive.Utils

  @expected_solr_fields_path Path.join(["solr", "fields.json"])

  setup :verify_on_exit!

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
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, solr_schema_response())
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
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, solr_schema_response())
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
      assert conn.path_info == ["schema"]
      Plug.Conn.resp(conn, 200, solr_missing_fields_response())
    end)

    assert {:error, %Hui.Error{reason: :einit}} = LastfmArchive.Load.check_solr_schema(url)
  end

  test "load a TSV file from the archive into Solr for a given user", %{bypass: bypass} do
    test_user = "load_test_user"
    tsv_file = Path.join(Utils.user_dir("load_test_user"), "tsv/2018.tsv.gz")

    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "#{bypass_url}", handler: "update", headers: headers}

    LastfmArchive.FileIOMock
    |> expect(:read, fn ^tsv_file -> {:ok, tsv_gzip_data()} end)

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert conn.method == "POST"
      assert body == solr_add_docs()

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
  end

  test "load_archive/2: load all TSV archive data into Solr via %Hui.URL{}", %{bypass: bypass} do
    test_user = "load_test_user"
    tsv_wildcard_path = Path.join(Utils.user_dir("load_test_user"), "**/*.gz")
    tsv_file = Path.join([Utils.user_dir("load_test_user"), "tsv", "2018.tsv.gz"])

    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "#{bypass_url}", handler: "update", headers: headers}

    LastfmArchive.PathIOMock |> expect(:wildcard, fn ^tsv_wildcard_path, _options -> [tsv_file] end)
    LastfmArchive.FileIOMock |> expect(:read, fn ^tsv_file -> {:ok, tsv_gzip_data()} end)

    Bypass.expect(bypass, fn conn ->
      case conn.method do
        "GET" ->
          assert conn.path_info == ["schema"] or conn.path_info == ["admin", "ping"]

        "POST" ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          assert body == solr_add_docs()
      end

      Plug.Conn.resp(conn, 200, solr_schema_response())
    end)

    capture_io(fn -> LastfmArchive.load_archive(test_user, url) end)
  end

  test "load_archive/2: load all TSV archive data into Solr via URL config key", %{bypass: bypass} do
    test_user = "load_test_user"
    tsv_wildcard_path = Path.join(Utils.user_dir("load_test_user"), "**/*.gz")
    tsv_file = Path.join([Utils.user_dir("load_test_user"), "tsv", "2018.tsv.gz"])

    bypass_url = "http://localhost:#{bypass.port}/"
    headers = [{"Content-type", "application/json"}]

    Application.put_env(:hui, :test_url, url: bypass_url, headers: headers, handler: "update")

    LastfmArchive.PathIOMock |> expect(:wildcard, fn ^tsv_wildcard_path, _options -> [tsv_file] end)
    LastfmArchive.FileIOMock |> expect(:read, fn ^tsv_file -> {:ok, tsv_gzip_data()} end)

    Bypass.expect(bypass, fn conn ->
      if conn.method == "GET" do
        assert conn.path_info == ["schema"] or conn.path_info == ["admin", "ping"]
      end

      Plug.Conn.resp(conn, 200, solr_schema_response())
    end)

    capture_io(fn -> LastfmArchive.load_archive(test_user, :test_url) end)
  end

  test "load_archive/2 handles malformed URLs" do
    test_user = "load_test_user"
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, :not_valid_url_config_key)
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, nil)
    assert {:error, %Hui.Error{reason: :einval}} == LastfmArchive.load_archive(test_user, "http://binary_url")
  end
end
