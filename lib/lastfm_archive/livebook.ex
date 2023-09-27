defmodule LastfmArchive.Livebook do
  @moduledoc """
  Livebook chart and text rendering.
  """
  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi
  alias VegaLite, as: Vl

  alias Explorer.DataFrame
  alias Explorer.Series

  require Explorer.DataFrame

  @cache LastfmArchive.Cache.Server
  @type user :: LastfmArchive.Behaviour.Archive.user()
  @type year :: integer()
  @type daily_playcounts :: %{
          {user, year} => %{data: list(%{count: integer(), date: String.t()}), total: integer(), max: integer()}
        }

  @doc """
  Display user name and total number of scrobbles to archive.
  """
  @spec info :: Kino.Markdown.t()
  def info(user \\ LastfmClient.default_user()) do
    impl = LastfmArchive.Behaviour.LastfmClient.impl()
    playcount_api = LastfmApi.new("user.getrecenttracks")
    info_api = LastfmApi.new("user.getinfo")
    time_range = {nil, nil}

    case {user, impl.info(user, info_api), impl.playcount(user, time_range, playcount_api)} do
      {"", _, _} ->
        Kino.Markdown.new("""
        Please specify a Lastfm user in configuration.
        """)

      {user, {:ok, {total, registered_time}}, {:ok, {_, latest_scrobble_time}}} ->
        Kino.Markdown.new("""
        For Lastfm user: **#{user}** with **#{total}** total number of scrobbles.
        - scrobbling since **#{registered_time |> DateTime.from_unix!() |> DateTime.to_date()}**
        - latest scrobble time **#{latest_scrobble_time |> DateTime.from_unix!() |> Calendar.strftime("%c")}**
        """)

      {_, _, _} ->
        Kino.Markdown.new("""
        Unable to fetch user info from Lastfm API, have you configured the API key?
        """)
    end
  end

  @doc """
  Display daily playcounts of scrobbles archived in VegaLite heatmaps.
  """
  @spec render_playcounts_heatmaps(user(), keyword(), module()) :: :ok
  def render_playcounts_heatmaps(user \\ LastfmClient.default_user(), opts \\ [], cache \\ @cache) do
    colour_scheme = Keyword.get(opts, :colour, "yellowgreenblue")
    stats = daily_playcounts_per_years(user, cache)
    global_max = stats |> Map.values() |> Stream.map(& &1.max) |> Enum.max()

    stats
    |> Enum.each(fn {{_user, year}, %{data: data}} ->
      render_heading(year, data)
      render_heatmap(data, year, global_max, colour_scheme)
    end)
  end

  defp render_heading(year, data) do
    stats = stats_per_year(data)

    Kino.Markdown.new("<small style=\"padding-left: 40px;\">Year <b>#{year}</b>,
      total <b>#{stats["total"]}</b>,
      per-day
      <b>#{stats["avg"] |> round()}</b> avg,
      <b>#{stats["median"] |> round()}</b> median,
      <b>#{stats["min"]}</b> min,
      <b>#{stats["max"]}</b> max
      </small>")
    |> Kino.render()
  end

  defp stats_per_year(counts) do
    DataFrame.new(counts)
    |> DataFrame.collect()
    |> DataFrame.summarise(
      avg: mean(count),
      median: median(count),
      min: min(count),
      max: max(count),
      total: sum(count)
    )
    |> DataFrame.to_rows()
    |> hd
  end

  defp render_heatmap(data, year, max, colour_scheme) do
    Vl.new(title: nil, width: 620, height: 80)
    |> Vl.transform(filter: "datum.count > 0 && datum.year == #{year}")
    |> Vl.data_from_values(data)
    |> Vl.mark(:rect, width: 9, height: 9, tooltip: true)
    |> Vl.encode_field(:x, "date",
      time_unit: :yearweek,
      type: :temporal,
      title: nil,
      axis: [format: "%b", offset: -8, domain: false, grid: false],
      scale: [domain: [[year: year, month: "jan", date: 1], [year: year, month: "dec", date: 31]]]
    )
    |> Vl.encode_field(:y, "date",
      time_unit: :yearday,
      type: :temporal,
      title: nil,
      axis: [format: "%a", offset: 16],
      sort: "descending"
    )
    |> Vl.encode_field(:color, "count",
      aggregate: :sum,
      type: :quantitative,
      legend: false,
      scale: [domain: [0, max], scheme: colour_scheme]
    )
    |> Vl.encode(:tooltip, [[field: "date", type: :temporal], [field: "count", type: :quantitative]])
    |> Vl.config(view: [stroke: nil])
    |> Kino.render()
  end

  @doc """
  Returns a list of daily scrobble playcounts and stats per years.
  """
  @spec daily_playcounts_per_years(user(), module()) :: daily_playcounts()
  def daily_playcounts_per_years(user \\ LastfmClient.default_user(), cache \\ @cache) do
    for {{user, year}, statuses} <- user |> LastfmArchive.Cache.load(cache), into: %{} do
      data = aggregate(statuses) |> List.flatten()

      {
        {user, year},
        %{
          data: data,
          max: Stream.map(data, & &1.count) |> Enum.max(),
          total: Stream.map(data, & &1.count) |> Enum.sum()
        }
      }
    end
  end

  defp aggregate(statuses) do
    statuses
    |> Enum.flat_map(fn {{from, _to}, {count, status}} ->
      case Enum.all?(status, &(&1 == :ok)) do
        true -> [{from, count}]
        false -> []
      end
    end)
    |> Enum.group_by(fn {from, _count} -> get_date(from) end, &elem(&1, 1))
    |> Enum.into([], fn {%{year: year} = date, counts} ->
      %{
        date: date |> to_string(),
        year: year,
        count: Enum.sum(counts)
      }
    end)
  end

  defp get_date(datetime), do: datetime |> DateTime.from_unix!() |> DateTime.to_date()

  @doc """
  Display faceted dataframe in VegaLite bubble plot showing first play and counts (size, colour).
  """
  @spec render_first_play_bubble_plot(DataFrame.t()) :: VegaLite.t()
  def render_first_play_bubble_plot(facet_dataframe) do
    {min_year, max_year} = find_first_play_min_max_years(facet_dataframe)

    data =
      facet_dataframe
      |> DataFrame.put(:first_play, Series.cast(facet_dataframe[:first_play], :date) |> Series.cast(:string))
      |> DataFrame.to_rows()

    Vl.new(title: nil, width: 800, height: 400)
    |> Vl.transform(calculate: "random()", as: "jitter")
    |> Vl.transform(filter: "datum.counts > 0")
    |> Vl.data_from_values(data)
    |> Vl.mark(:circle, tooltip: true)
    |> Vl.encode_field(:x, "first_play",
      time_unit: :yearmonth,
      type: :temporal,
      title: nil,
      axis: [format: "%Y"],
      scale: [domain: [[year: min_year, month: "jan", date: 1], [year: max_year, month: "dec", date: 31]]]
    )
    |> Vl.encode_field(:x_offset, "jitter", type: :quantitative)
    |> Vl.encode_field(:y_offset, "jitter", type: :quantitative)
    |> Vl.encode_field(:y, "first_play",
      time_unit: :date,
      type: :temporal,
      title: nil,
      axis: [format: "%d"]
      # sort: "ascending"
    )
    |> Vl.encode_field(:size, "counts",
      type: :quantitative,
      scale: [type: "linear", range_max: 1000, range_min: 2],
      legend: false
    )
    |> Vl.encode_field(:color, "counts",
      type: :nominal,
      opacity: 0.5,
      scale: [scheme: "turbo"],
      legend: false
    )
    |> Vl.encode(:tooltip, [
      [field: "artist", type: :nominal],
      [field: "counts", type: :quantitative],
      [field: "first_play", type: :temporal]
    ])
  end

  defp find_first_play_min_max_years(df) do
    df = df |> DataFrame.summarise(min: min(first_play), max: max(first_play)) |> DataFrame.to_rows() |> hd
    %{year: min_year} = df["min"]
    %{year: max_year} = df["max"]

    {min_year, max_year}
  end
end
