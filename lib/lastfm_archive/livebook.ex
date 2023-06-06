defmodule LastfmArchive.Livebook do
  @moduledoc """
  Livebook chart and text rendering.
  """

  alias LastfmArchive.LastfmClient

  @type monthy_count :: %{count: integer(), date: String.t()}

  @doc """
  Display user name and total number of scrobbles to archive.
  """
  @spec info :: Kino.Markdown.t()
  def info do
    case {LastfmClient.default_user(), LastfmArchive.info()} do
      {"", _} ->
        Kino.Markdown.new("""
        Please specify a Lastfm user in configuration.
        """)

      {user, {:ok, {total, _}}} ->
        Kino.Markdown.new("""
        For Lastfm user: **#{user}** with **#{total}** total number of scrobbles.
        """)

      {_, _} ->
        Kino.Markdown.new("""
        Unable to fetch user info from Lastfm API, have you configured the API key?
        """)
    end
  end

  @doc """
  Returns a list of monthly counts of the scrobbles archived so far.
  """
  @spec status(module(), keyword()) :: list(monthy_count)
  def status(cache \\ LastfmArchive.Cache, options \\ []) do
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
