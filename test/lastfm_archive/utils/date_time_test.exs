defmodule LastfmArchive.Utils.DateTimeTest do
  use ExUnit.Case, async: true
  import LastfmArchive.Utils.DateTime, only: [daily_time_ranges: 1, time_for_year: 2, year_range: 1]

  test "daily_time_ranges/1" do
    {:ok, from, 0} = DateTime.from_iso8601("2010-12-23T18:50:07Z")
    {:ok, to, 0} = DateTime.from_iso8601("2011-01-13T11:06:25Z")

    time_ranges = daily_time_ranges({DateTime.to_unix(from), DateTime.to_unix(to)})

    for day <- Date.range(Date.from_erl!({2010, 12, 23}), Date.from_erl!({2011, 1, 13})) do
      {:ok, from, _} = DateTime.from_iso8601("#{day}T00:00:00Z")
      {:ok, to, _} = DateTime.from_iso8601("#{day}T23:59:59Z")

      assert {DateTime.to_unix(from), DateTime.to_unix(to)} in time_ranges
    end
  end

  test "time_for_year/2" do
    {:ok, registered_date, 0} = DateTime.from_iso8601("2018-01-13T11:06:25Z")
    {:ok, last_scrobble_date, 0} = DateTime.from_iso8601("2021-05-04T12:55:25Z")

    assert {1_577_836_800, 1_609_459_199} ==
             time_for_year(2020, {DateTime.to_unix(registered_date), DateTime.to_unix(last_scrobble_date)})
  end

  test "year_range/1 from first and latest scrobble times" do
    {:ok, from, 0} = DateTime.from_iso8601("2008-12-23T18:50:07Z")
    {:ok, to, 0} = DateTime.from_iso8601("2021-01-13T11:06:25Z")

    year_range = year_range({DateTime.to_unix(from), DateTime.to_unix(to)})
    for year <- 2008..2021, do: assert(year in year_range)
  end
end
