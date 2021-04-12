defmodule TransformTest do
  use ExUnit.Case, async: false

  # TODO: rewrite this with File IO mocks in 

  # import ExUnit.CaptureIO

  # @test_data_dir Application.get_env(:lastfm_archive, :data_dir)

  # test "read compressed archive data for a given user, file location" do
  #   test_user = "transform_test_user"
  #   File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
  #   on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

  #   assert {:ok, lastfm_tracks} = LastfmArchive.Transform.read(test_user, "200_34.gz")
  #   assert length(lastfm_tracks["recenttracks"]["track"]) > 0
  # end

  # test "transform a page of compressed archive data for a given user, file location" do
  #   test_user = "transform_test_user"
  #   File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
  #   on_exit(fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end)

  #   tracks = LastfmArchive.Transform.transform(test_user, "200_34.gz")
  #   assert length(tracks) > 0
  # end

  # @tag :disk_write
  # test "transform all data and create TSV files for a given user" do
  #   test_user = "transform_test_user"
  #   File.cp_r("test/data/#{Application.get_env(:lastfm_archive, :user)}", "#{@test_data_dir}/#{test_user}")
  #   fn -> File.rm_rf(Path.join(@test_data_dir, "#{test_user}")) end

  #   json_source = Path.join([@test_data_dir, test_user, "200_34.gz"])
  #   test_user_data_dir = Path.join([@test_data_dir, test_user, "2007"])

  #   File.mkdir_p(test_user_data_dir)
  #   File.cp(json_source, Path.join(test_user_data_dir, "200_34.gz"))

  #   capture_io(fn -> LastfmArchive.transform_archive(test_user) end)
  #   assert File.dir?(Path.join([@test_data_dir, test_user, "tsv"]))

  #   tsv_filepath = Path.join([@test_data_dir, test_user, "tsv", "2007.tsv.gz"])
  #   assert File.exists?(tsv_filepath)

  #   {_status, file_io} = File.open(tsv_filepath, [:read, :compressed, :utf8])
  #   {_, tracks} = IO.read(file_io, :all) |> String.split("\n") |> List.pop_at(0)
  #   File.close(file_io)

  #   assert length(tracks) > 0

  #   first_track = tracks |> List.first()
  #   assert String.match?(first_track, ~r/test_user_1187364186_6601\t今天沒回家\t1187364186/)

  #   assert capture_io(fn -> LastfmArchive.transform_archive(test_user) end) ==
  #            "\nTSV file archive exists, skipping 2007 scrobbles.\n"
  # end
end
