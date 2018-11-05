defmodule TransformTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @test_data_dir Path.join([".", "test", "data"])

  setup do
    configured_dir = Application.get_env :lastfm_archive, :data_dir
    on_exit fn ->
      Application.put_env :lastfm_archive, :data_dir, configured_dir
    end
  end

  test "read compressed archive data for a given user, file location" do
    Application.put_env :lastfm_archive, :data_dir, @test_data_dir

    assert {:ok, lastfm_tracks} = LastfmArchive.Transform.read("test_user", "200_34.gz")
    assert length(lastfm_tracks["recenttracks"]["track"]) > 0
  end

  test "transform a page of compressed archive data for a given user, file location" do
    Application.put_env :lastfm_archive, :data_dir, @test_data_dir

    tracks = LastfmArchive.Transform.transform("test_user", "200_34.gz")
    assert length(tracks) > 0
  end

  @tag :disk_write
  test "transform all data and create TSV files for a given user" do
    user = "test_user"

    test_data_dir = Path.join([".", "lastfm_data", "test", "transform", "t1"])
    unless File.exists?(test_data_dir), do: File.mkdir_p test_data_dir

    json_source = Path.join [@test_data_dir, user, "200_34.gz"]
    test_user_data_dir = Path.join [test_data_dir, user, "2007"]
    File.mkdir_p test_user_data_dir
    File.cp json_source, Path.join(test_user_data_dir, "200_34.gz")

    Application.put_env :lastfm_archive, :data_dir, test_data_dir

    capture_io(fn -> LastfmArchive.transform_archive(user) end)
    assert File.dir? Path.join([test_data_dir, user, "tsv"])

    tsv_filepath = Path.join([test_data_dir, user, "tsv", "2007.tsv.gz"])
    assert File.exists? tsv_filepath

    {_status, file_io} = File.open(tsv_filepath, [:read, :compressed, :utf8])
    {_, tracks} = IO.read(file_io, :all) |> String.split("\n") |> List.pop_at(0)
    File.close(file_io)

    assert length(tracks) > 0

    first_track = tracks |> List.first
    assert String.match? first_track, ~r/test_user_1187364186_6601\t今天沒回家\t1187364186/

    assert capture_io(fn -> LastfmArchive.transform_archive("test_user") end) == "\nTSV file archive exists, skipping 2007 scrobbles.\n"
  after
    test_data_dir = Path.join([".", "lastfm_data", "test", "transform", "t1"])
    File.rm_rf test_data_dir
  end

end
