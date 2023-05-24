defmodule LastfmArchive.UtilsTest do
  use ExUnit.Case, async: true

  import Mox
  import Fixtures.Archive

  alias LastfmArchive.Utils
  alias LastfmArchive.Behaviour.Archive

  test "build_time_range/1 provides daily time range" do
    {:ok, from, 0} = DateTime.from_iso8601("2010-12-23T18:50:07Z")
    {:ok, to, 0} = DateTime.from_iso8601("2011-01-13T11:06:25Z")

    time_ranges = Utils.build_time_range({DateTime.to_unix(from), DateTime.to_unix(to)})

    for day <- Date.range(Date.from_erl!({2010, 12, 23}), Date.from_erl!({2011, 1, 13})) do
      {:ok, from, _} = DateTime.from_iso8601("#{day}T00:00:00Z")
      {:ok, to, _} = DateTime.from_iso8601("#{day}T23:59:59Z")

      assert {DateTime.to_unix(from), DateTime.to_unix(to)} in time_ranges
    end
  end

  test "build_time_range/1 provides year time range" do
    {:ok, registered_date, 0} = DateTime.from_iso8601("2018-01-13T11:06:25Z")
    {:ok, last_scrobble_date, 0} = DateTime.from_iso8601("2021-05-04T12:55:25Z")

    assert {1_577_836_800, 1_609_459_199} ==
             Utils.build_time_range(2020, %Archive{
               creator: "a_lastfm_user",
               temporal: {DateTime.to_unix(registered_date), DateTime.to_unix(last_scrobble_date)}
             })
  end

  test "year_range/1 from first and latest scrobble times" do
    {:ok, from, 0} = DateTime.from_iso8601("2008-12-23T18:50:07Z")
    {:ok, to, 0} = DateTime.from_iso8601("2021-01-13T11:06:25Z")

    year_range = Utils.year_range({DateTime.to_unix(from), DateTime.to_unix(to)})

    for year <- 2008..2021 do
      assert year in year_range
    end
  end

  test "read/2 file from the archive for a given user and file location" do
    test_user = "load_test_user"
    tsv_file = Path.join(Utils.user_dir("load_test_user"), "tsv/2018.tsv.gz")
    non_existing_file = Path.join(Utils.user_dir("load_test_user"), "non_existing_file.tsv.gz")

    LastfmArchive.FileIOMock
    |> expect(:read, fn ^non_existing_file -> {:error, :enoent} end)
    |> expect(:read, fn ^tsv_file -> {:ok, tsv_gzip_data()} end)

    assert {:error, :enoent} = Utils.read(test_user, "non_existing_file.tsv.gz")
    assert {:ok, resp} = Utils.read(test_user, "tsv/2018.tsv.gz")

    [header | scrobbles] = resp |> String.split("\n")
    assert header == LastfmArchive.Transform.tsv_headers()
    assert length(scrobbles) > 0
  end
end
