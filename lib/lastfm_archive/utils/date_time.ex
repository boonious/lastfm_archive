defmodule LastfmArchive.Utils.DateTime do
  @moduledoc false

  def daily_time_ranges({from, to}) do
    from = DateTime.from_unix!(from) |> DateTime.to_date()
    to = DateTime.from_unix!(to) |> DateTime.to_date()
    Enum.map(Date.range(from, to), &iso8601_to_unix("#{&1}T00:00:00Z", "#{&1}T23:59:59Z"))
  end

  def date_in_range?(%{temporal: {first, latest}}, {from, to}), do: from in first..latest || to in first..latest

  def date(from) when is_integer(from), do: DateTime.from_unix!(from) |> DateTime.to_date()
  def date({from, _to}) when is_integer(from), do: DateTime.from_unix!(from) |> DateTime.to_date()

  def iso8601_to_unix(from, to) do
    {:ok, from, _} = DateTime.from_iso8601(from)
    {:ok, to, _} = DateTime.from_iso8601(to)

    {DateTime.to_unix(from), DateTime.to_unix(to)}
  end

  def month_range(year, scrobbles_time_range) do
    {from, to} = time_for_year(year, scrobbles_time_range)
    %Date{month: first_month} = DateTime.from_unix!(from) |> DateTime.to_date()
    %Date{month: last_month} = DateTime.from_unix!(to) |> DateTime.to_date()

    for month <- 1..12, month <= last_month, month >= first_month do
      %Date{year: year, day: 1, month: month}
    end
  end

  def time_for_year(year, {registered_time, last_scrobble_time}) when is_integer(year) do
    {from, to} = iso8601_to_unix("#{year}-01-01T00:00:00Z", "#{year}-12-31T23:59:59Z")

    from = if from <= registered_time, do: registered_time, else: from
    to = if to >= last_scrobble_time, do: last_scrobble_time, else: to

    {from, to}
  end

  def year_range({from, to}), do: DateTime.from_unix!(from).year..DateTime.from_unix!(to).year
end
