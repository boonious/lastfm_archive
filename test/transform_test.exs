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

  @tag :dev
  test "transform all data and create TSV files for a given user" do
    user = "test_user"

    test_data_dir = Path.join([".", "lastfm_data", "test", "transform", "t1"])
    unless File.exists?(test_data_dir), do: File.mkdir_p test_data_dir

    json_source = Path.join [@test_data_dir, user, "200_34.gz"]
    test_user_data_dir = Path.join [test_data_dir, user, "2007"]
    File.mkdir_p test_user_data_dir
    File.cp json_source, Path.join(test_user_data_dir, "200_34.gz")

    Application.put_env :lastfm_archive, :data_dir, test_data_dir

    LastfmArchive.transform_archive(user)
    assert File.dir? Path.join([test_data_dir, user, "tsv"])

    tsv_filepath = Path.join([test_data_dir, user, "tsv", "2007.tsv.gz"])
    assert File.exists? tsv_filepath

  after
    test_data_dir = Path.join([".", "lastfm_data", "test", "transform", "t1"])
    File.rm_rf test_data_dir
  end

end
