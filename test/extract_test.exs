defmodule ExtractTest do
  use ExUnit.Case, async: true
  import TestHelpers

  doctest LastfmArchive

  @lastfm_api_params %{"method" => "user.getrecenttracks", 
                       "api_key" => Application.get_env(:elixirfm, :api_key), 
                       "user" => Application.get_env(:lastfm_archive, :user)}

  @default_data_dir "./lastfm_data/"

  # testing with Bypass
  setup do
    lastfm_ws = Application.get_env :elixirfm, :lastfm_ws
    configured_dir = Application.get_env :lastfm_archive, :data_dir

    bypass = Bypass.open

    on_exit fn ->
      Application.put_env :elixirfm, :lastfm_ws, lastfm_ws
      Application.put_env :lastfm_archive, :data_dir, configured_dir
    end

    [bypass: bypass]
  end

  test "extract/0 requests params for the configured user", context do
    test_conn_params(context.bypass, @lastfm_api_params)
    LastfmArchive.extract
  end

  test "extract/1 requests params for a specific user", context do
    test_conn_params(context.bypass, %{@lastfm_api_params | "user" => "a_lastfm_user"})
    LastfmArchive.extract("a_lastfm_user")
  end

  test "write/2 compressed data to the default file location" do
    user = Application.get_env(:lastfm_archive, :user) || ""
    Application.put_env :lastfm_archive, :data_dir, @default_data_dir

    file_path = Path.join ["#{@default_data_dir}", "#{user}", "1.gz"]
    on_exit fn -> File.rm file_path end

    # use mocked data when available
    LastfmArchive.write("test")
    assert File.exists? file_path
    assert "test" == File.read!(file_path) |> :zlib.gunzip
  end

  test "write/2 compressed data to the configured file location" do
    user = Application.get_env(:lastfm_archive, :user) || ""
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir

    file_path = Path.join ["#{data_dir}", "#{user}", "1.gz"]
    on_exit fn -> File.rm file_path end

    # use mocked data when available
    LastfmArchive.write("test")
    assert File.exists? file_path
    assert "test" == File.read!(file_path) |> :zlib.gunzip
  end

end
