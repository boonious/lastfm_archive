defmodule LastfmArchive.UtilsTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Utils

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
    assert {1_609_459_200, 1_640_995_199} == Utils.build_time_range(2021)
  end

  test "year_range/1 from first and latest scrobble times" do
    {:ok, from, 0} = DateTime.from_iso8601("2008-12-23T18:50:07Z")
    {:ok, to, 0} = DateTime.from_iso8601("2021-01-13T11:06:25Z")

    year_range = Utils.year_range({DateTime.to_unix(from), DateTime.to_unix(to)})

    for year <- 2008..2021 do
      assert year in year_range
    end
  end
end
