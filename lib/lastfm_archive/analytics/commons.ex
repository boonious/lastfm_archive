defmodule LastfmArchive.Analytics.Commons do
  @moduledoc """
  Common data frame analytics functions.
  """

  alias Explorer.DataFrame
  require Explorer.DataFrame

  import Explorer.Series, only: [equal: 2]
  import LastfmArchive.Analytics.Settings

  @type data_frame :: LastfmArchive.Behaviour.Analytics.data_frame()
  @type group :: LastfmArchive.Behaviour.Analytics.group()

  @doc """
  Compute frequency for a columns subset, filter untitled albums.
  """
  @spec frequencies(data_frame(), group()) :: data_frame()
  def frequencies(df, group) do
    group = group |> List.wrap()

    case "album" in group do
      true -> df |> DataFrame.filter(album != "")
      false -> df
    end
    |> DataFrame.frequencies(group)
  end

  @doc """
  Calculate stats for a single group such as "artist", "album".

  Stats include:
  - `years_freq`: frequency of yearly occurrance per group
  - `total_plays`: total number of plays per group

  The function also pivots and creates additional `year` columns
  with annual play counts per group.
  """
  @spec create_group_stats(data_frame(), String.t()) :: data_frame()
  def create_group_stats(df, group) do
    df
    |> DataFrame.group_by(group)
    |> DataFrame.collect()
    |> DataFrame.mutate(years_freq: count(year), total_plays: sum(counts))
    |> DataFrame.pivot_wider("year", ["counts"])
    |> DataFrame.ungroup(group)
  end

  def create_facet_stats(df, df_source) do
    df
    |> DataFrame.to_rows()
    |> then(fn facets ->
      facet_type = facets |> hd |> facet_type()

      {
        df,
        for {facet, index} <- facets |> Enum.with_index(), into: %{"type" => facet_type} do
          create_facet_stats(df_source, facet, index)
        end
      }
    end)
  end

  def create_facet_stats(df, facet, index) do
    facet_type = facet |> facet_type()
    mutation_fun = facet_mutation_fun()[facet_type]

    # stop gap until "name" col in archive is renamed to "track"
    facet_type = if facet_type == :track, do: :name, else: facet_type
    facet_value = facet["#{facet_type}"]
    filter_fun = &equal(&1["#{facet_type}"], facet_value)

    {index, df |> filter_mutate_row("#{facet_type}", filter_fun, mutation_fun)}
  end

  defp filter_mutate_row(df, column, filter_fun, mutate_fun) do
    df
    |> DataFrame.filter_with(filter_fun)
    |> DataFrame.select(["name", "album", "artist", "year"])
    |> DataFrame.group_by(column)
    |> DataFrame.collect()
    |> DataFrame.mutate_with(mutate_fun)
    |> DataFrame.distinct()
  end

  @doc """
  Rank data frame by total plays count and return top n rows.
  """
  @spec most_played(data_frame(), list()) :: data_frame()
  def most_played(df, opts \\ []) do
    opts = Keyword.validate!(opts, default_opts())

    df
    |> DataFrame.arrange_with(&[desc: &1[opts[:sort_by]]])
    |> DataFrame.head(opts[:rows])
  end

  def default_opts, do: [rows: 5, sort_by: "total_plays"]
end
