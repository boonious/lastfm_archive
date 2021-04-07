defmodule LastfmArchive.Utils do
  @moduledoc false

  @data_dir Application.get_env(:lastfm_archive, :data_dir, "./archive_data/")
  @metadata_file ".archive"

  @doc """
  Generate {from, to} time ranges for querying LastFM API based on
  the first and last scrobble unix timestamps.

  The time ranges are devised on the basis that older scrobbles
  (up to this year) are extracted and stored yearly at maximum throughput
  permitted by Lastfm API. The latest or current year scrobbles
  are extracted "up-to-last-month" and then on a daily basis.

  All subsequent extraction or "sync" is done on a daily "delta" basis
  without the need to re-download or querying the API again for older
  scrobbles.
  """
  def build_time_ranges({first_scrobble_data, now}) do
    {:ok, from} = DateTime.from_unix(first_scrobble_data)
    {:ok, to} = DateTime.from_unix(now)

    year_range = build_time_range(from.year..(to.year - 1))
    this_year_to_end_of_last_month_range = build_time_range(to)
    this_month_daily_range = build_time_range(Date.from_erl!({to.year, to.month, 1}), DateTime.to_date(to))

    year_range ++ this_year_to_end_of_last_month_range ++ this_month_daily_range
  end

  # build yearly time ranges
  defp build_time_range(from_year..to_year) when from_year <= to_year do
    Enum.map(from_year..to_year, &build_time_range(&1))
  end

  defp build_time_range(_from_year.._to_year), do: []

  defp build_time_range(year) when is_integer(year) do
    build_time_range("#{year}-01-01T00:00:00Z", "#{year}-12-31T23:59:59Z")
  end

  # build up-to-last-month for this year scrobbles
  defp build_time_range(%DateTime{month: 1}), do: []

  defp build_time_range(%DateTime{year: year, month: month}) do
    first_of_this_year = Date.from_erl!({year, 1, 1})
    end_of_last_month = Date.from_erl!({year, month - 1, 1}) |> Date.end_of_month()

    [build_time_range("#{first_of_this_year}T00:00:00Z", "#{end_of_last_month}T23:59:59Z")]
  end

  # build daily time ranges
  defp build_time_range(from = %Date{}, to = %Date{}) do
    Enum.map(Date.range(from, to), &build_time_range("#{&1}T00:00:00Z", "#{&1}T23:59:59Z"))
  end

  defp build_time_range(from, to) do
    {:ok, from, _} = DateTime.from_iso8601(from)
    {:ok, to, _} = DateTime.from_iso8601(to)

    {DateTime.to_unix(from), DateTime.to_unix(to)}
  end

  def archive_dir(options \\ []), do: Keyword.get(options, :data_dir, @data_dir)

  def metadata_path(archive_id, options), do: Path.join([archive_dir(options), archive_id, @metadata_file])

  def display_progress(archive) do
    IO.puts("Archiving #{archive.extent} scrobbles for #{archive.creator}")
  end

  def display_progress({from, to}, playcount, pages) do
    from_date = DateTime.from_unix!(from) |> DateTime.to_date()
    to_date = DateTime.from_unix!(to) |> DateTime.to_date()

    IO.puts("\n")
    IO.puts("#{from_date} - #{to_date}")
    IO.puts("#{playcount} scrobble(s)")
    IO.puts("#{pages} page(s)")
  end
end
