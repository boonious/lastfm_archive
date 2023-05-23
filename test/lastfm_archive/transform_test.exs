defmodule LastfmArchive.TransformTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  import Fixtures.Archive
  import Mox

  alias LastfmArchive.Utils

  setup :verify_on_exit!

  test "transform a page of compressed archive data for a given user, file location" do
    test_user = "transform_test_user"
    gzip_path = Path.join(Utils.user_dir(test_user), "200_34.gz")

    LastfmArchive.FileIOMock |> expect(:read, fn ^gzip_path -> {:ok, gzip_data()} end)
    [headers | tracks] = LastfmArchive.Transform.transform(test_user, "200_34.gz")

    assert length(tracks) > 0
    assert headers == LastfmArchive.Transform.tsv_headers()

    assert String.match?(tracks |> hd, ~r/test_user_1187364186_6601\t今天沒回家\t1187364186/)
  end

  test "transform all data and create TSV files for a given user" do
    test_user = "transform_test_user"
    gzip_wildcard_path = Path.join(Utils.user_dir(test_user), "**/*.gz")
    gzip_path = Path.join([Utils.user_dir(test_user), "2007", "200_34.gz"])
    tsv_dir = Path.join(Utils.user_dir(test_user), "tsv")
    tsv_write_path = Path.join([Utils.user_dir(test_user), "tsv", "2007.tsv.gz"])

    LastfmArchive.PathIOMock |> expect(:wildcard, fn ^gzip_wildcard_path, _options -> [gzip_path] end)

    LastfmArchive.FileIOMock
    |> expect(:exists?, fn ^tsv_dir -> false end)
    |> expect(:exists?, fn ^tsv_write_path -> false end)
    |> expect(:mkdir_p, fn ^tsv_dir -> :ok end)
    |> expect(:read, fn ^gzip_path -> {:ok, gzip_data()} end)
    |> expect(:write, fn ^tsv_write_path, _tracks, [:compressed] -> :ok end)

    capture_io(fn -> LastfmArchive.transform_archive(test_user) end)

    # assert capture_io(fn -> LastfmArchive.transform_archive(test_user) end) ==
    #          "\nTSV file archive exists, skipping 2007 scrobbles.\n"
  end

  test "doesn't transform already existing data" do
    test_user = "transform_test_user"
    gzip_wildcard_path = Path.join(Utils.user_dir(test_user), "**/*.gz")
    gzip_path = Path.join([Utils.user_dir(test_user), "2007", "200_34.gz"])

    LastfmArchive.PathIOMock |> expect(:wildcard, 1, fn ^gzip_wildcard_path, _options -> [gzip_path] end)
    LastfmArchive.FileIOMock |> stub(:exists?, fn _path -> true end)

    assert capture_io(fn -> LastfmArchive.transform_archive(test_user) end) ==
             "\nTSV file archive exists, skipping 2007 scrobbles.\n"
  end

  test "tsv_headers" do
    assert LastfmArchive.Transform.tsv_headers() ==
             "id\tname\tscrobble_date\tscrobble_date_iso\tmbid\turl\tartist\tartist_mbid\tartist_url\talbum\talbum_mbid"
  end
end
