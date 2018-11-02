defmodule TransformTest do
  use ExUnit.Case, async: true

  @test_data_dir Path.join([".", "test", "data"])

  setup do
    configured_dir = Application.get_env :lastfm_archive, :data_dir
    on_exit fn ->
      Application.put_env :lastfm_archive, :data_dir, configured_dir
    end
  end

  test "read compressed archive data from a given file location" do
    Application.put_env :lastfm_archive, :data_dir, @test_data_dir

    assert {:ok, lastfm_tracks} = LastfmArchive.Transform.read("test_user", "200_34.gz")
    assert length(lastfm_tracks["recenttracks"]["track"]) > 0
  end

end
