defmodule LastfmArchive.UtilsTest do
  use ExUnit.Case, async: true
  alias LastfmArchive.Utils

  describe "build_time_ranges/1" do
    setup do
      {:ok, first_scrobble_date, 0} = DateTime.from_iso8601("2009-06-23T18:50:07Z")
      {:ok, last_scrobble_date, 0} = DateTime.from_iso8601("2011-05-13T11:06:25Z")

      unix_time_ranges =
        Utils.build_time_ranges({DateTime.to_unix(first_scrobble_date), DateTime.to_unix(last_scrobble_date)})

      date_ranges =
        Enum.map(unix_time_ranges, fn {from, to} -> {DateTime.from_unix!(from), DateTime.from_unix!(to)} end)

      %{date_ranges: date_ranges}
    end

    test "provides yearly time ranges for older scrobbles", %{date_ranges: date_ranges} do
      assert {~U[2009-01-01 00:00:00Z], ~U[2009-12-31 23:59:59Z]} in date_ranges
      assert {~U[2010-01-01 00:00:00Z], ~U[2010-12-31 23:59:59Z]} in date_ranges
      refute {~U[2011-01-01 00:00:00Z], ~U[2011-12-31 23:59:59Z]} in date_ranges
    end

    test "provides to-up-last-month time range for this year scrobbles", %{date_ranges: date_ranges} do
      assert {~U[2011-01-01 00:00:00Z], ~U[2011-04-30 23:59:59Z]} in date_ranges
    end

    test "provides daily time range for the latest scrobbles", %{date_ranges: date_ranges} do
      for day <- Date.range(Date.from_erl!({2011, 5, 1}), Date.from_erl!({2011, 5, 13})) do
        {:ok, from, _} = DateTime.from_iso8601("#{day}T00:00:00Z")
        {:ok, to, _} = DateTime.from_iso8601("#{day}T23:59:59Z")

        assert {from, to} in date_ranges
      end
    end

    test "does not provide to-up-last-month time range when last scrobble date is in January" do
      {:ok, first_scrobble_date, 0} = DateTime.from_iso8601("2010-06-23T18:50:07Z")
      {:ok, last_scrobble_date, 0} = DateTime.from_iso8601("2011-01-04T11:06:25Z")

      unix_time_ranges =
        Utils.build_time_ranges({DateTime.to_unix(first_scrobble_date), DateTime.to_unix(last_scrobble_date)})

      date_ranges =
        Enum.map(unix_time_ranges, fn {from, to} -> {DateTime.from_unix!(from), DateTime.from_unix!(to)} end)

      refute {~U[2011-01-01 00:00:00Z], ~U[2011-01-31 23:59:59Z]} in date_ranges

      assert [
               {~U[2010-01-01 00:00:00Z], ~U[2010-12-31 23:59:59Z]},
               {~U[2011-01-01 00:00:00Z], ~U[2011-01-01 23:59:59Z]},
               {~U[2011-01-02 00:00:00Z], ~U[2011-01-02 23:59:59Z]},
               {~U[2011-01-03 00:00:00Z], ~U[2011-01-03 23:59:59Z]},
               {~U[2011-01-04 00:00:00Z], ~U[2011-01-04 23:59:59Z]}
             ] == date_ranges
    end

    test "does not provide yearly time range without previous year scrobbles" do
      {:ok, first_scrobble_date, 0} = DateTime.from_iso8601("2021-02-05T18:50:07Z")
      {:ok, last_scrobble_date, 0} = DateTime.from_iso8601("2021-03-03T11:06:25Z")

      unix_time_ranges =
        Utils.build_time_ranges({DateTime.to_unix(first_scrobble_date), DateTime.to_unix(last_scrobble_date)})

      date_ranges =
        Enum.map(unix_time_ranges, fn {from, to} -> {DateTime.from_unix!(from), DateTime.from_unix!(to)} end)

      refute {~U[2020-01-01 00:00:00Z], ~U[2020-12-31 23:59:59Z]} in date_ranges

      assert [
               {~U[2021-01-01 00:00:00Z], ~U[2021-02-28 23:59:59Z]},
               {~U[2021-03-01 00:00:00Z], ~U[2021-03-01 23:59:59Z]},
               {~U[2021-03-02 00:00:00Z], ~U[2021-03-02 23:59:59Z]},
               {~U[2021-03-03 00:00:00Z], ~U[2021-03-03 23:59:59Z]}
             ] == date_ranges
    end
  end
end
