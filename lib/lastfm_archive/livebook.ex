defmodule LastfmArchive.Livebook do
  @moduledoc """
  Livebook chart and text rendering.
  """

  alias LastfmArchive.LastfmClient.Impl, as: LastfmClient
  alias LastfmArchive.LastfmClient.LastfmApi
  alias VegaLite, as: Vl

  @cache LastfmArchive.Cache
  @type monthy_count :: %{count: integer(), date: String.t()}

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
  Monthly playcounts of scrobbles archived so far - VegaLite heatmap.
  """
  @spec monthly_playcounts_heatmap(module()) :: VegaLite.t()
  def monthly_playcounts_heatmap(cache \\ @cache) do
    Vl.new(title: "")
    |> Vl.data_from_values(status(cache))
    |> Vl.mark(:rect)
    |> Vl.encode_field(:x, "date",
      time_unit: :month,
      type: :ordinal,
      title: "Month",
      axis: [label_angle: 0, format: "%m"]
    )
    |> Vl.encode_field(:y, "date",
      time_unit: :year,
      type: :ordinal,
      title: "Year"
    )
    |> Vl.encode_field(:color, "count",
      aggregate: :max,
      type: :quantitative,
      legend: [title: nil]
    )
    |> Vl.config(view: [stroke: nil])
  end

  @doc """
  Yearly playcounts of scrobbles archived so far - Kino data table.
  """
  @spec yearly_playcounts_table(module()) :: Kino.JS.Live.t()
  def yearly_playcounts_table(cache \\ @cache) do
    status(cache, granularity: :yearly)
    |> Kino.DataTable.new(keys: [:year, :count], name: "")
  end

  @doc """
  Returns a list of monthly playcounts of scrobbles archived so far.
  """
  @spec status(module(), keyword()) :: list(monthy_count)
  def status(cache \\ @cache, options \\ []) do
    granularity = Keyword.get(options, :granularity, :monthly)

    LastfmClient.default_user()
    |> LastfmArchive.Cache.load(cache)
    |> Enum.map(fn {{_user, year}, statuses} -> aggregate_counts(year, statuses, granularity) end)
    |> List.flatten()
  end

  defp aggregate_counts(_year, statuses, :monthly) do
    statuses
    |> Enum.flat_map(fn {{from, _to}, {count, status}} ->
      case Enum.all?(status, &(&1 == :ok)) do
        true -> [{from, count}]
        false -> []
      end
    end)
    |> Enum.group_by(fn {from, _count} -> first_day_of_month(from) end, &elem(&1, 1))
    |> Enum.into([], fn {day, counts} -> %{date: day, count: Enum.sum(counts)} end)
  end

  defp aggregate_counts(year, statuses, :yearly) do
    statuses
    |> Enum.flat_map(fn {{_from, _to}, {count, status}} ->
      case Enum.all?(status, &(&1 == :ok)) do
        true -> [count]
        false -> []
      end
    end)
    |> Enum.sum()
    |> then(fn playcount -> %{year: year, count: playcount} end)
  end

  defp first_day_of_month(datetime) do
    %DateTime{month: month, year: year} = datetime |> DateTime.from_unix!()
    %Date{month: month, year: year, day: 1} |> to_string()
  end
end
