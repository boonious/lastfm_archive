defmodule LastfmArchive.Behaviour.Analytics do
  @moduledoc """
  Behaviour, macro and functions for Explorer.DataFrame analytics
  """

  alias Explorer.DataFrame
  alias Explorer.Series

  require Explorer.DataFrame
  import LastfmArchive.Analytics.Settings

  @type data_frame :: DataFrame.t()
  @type data_frame_stats :: %{
          album: %{count: integer()},
          artist: %{count: integer()},
          datetime: %{count: integer()},
          id: %{count: integer()},
          name: %{count: integer()},
          year: %{count: integer(), max: integer(), min: integer()}
        }

  @type group :: DataFrame.column_name() | DataFrame.column_names()
  @type options :: Keyword.t()

  @type top_facets :: DataFrame.t()
  @type top_facets_stats :: %{integer() => data_frame()}

  @type facets :: {top_facets(), top_facets_stats()}

  @callback data_frame(format: atom()) :: {:ok, data_frame()} | {:error, term}
  @callback data_frame_stats(data_frame()) :: data_frame_stats()

  for facet <- facets() do
    @callback unquote(:"top_#{facet}s")(data_frame(), options()) :: facets()
    @callback unquote(:"sample_#{facet}s")(data_frame(), options()) :: facets()
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LastfmArchive.Behaviour.Analytics

      import LastfmArchive.Analytics.Commons,
        only: [create_group_stats: 2, create_facet_stats: 2, frequencies: 3, most_played: 2, sample: 2]

      @impl true
      def data_frame_stats(df) do
        for {column, series} <- df |> DataFrame.collect() |> DataFrame.to_series(atom_keys: true), into: %{} do
          case series |> Series.dtype() do
            :string ->
              {column, %{count: series |> Series.distinct() |> Series.count()}}

            _ ->
              {column,
               %{
                 count: series |> Series.distinct() |> Series.count(),
                 max: series |> Series.max(),
                 min: series |> Series.min()
               }}
          end
        end
      end

      for facet <- Keyword.fetch!(opts, :facets) do
        @impl true
        def unquote(:"top_#{facet}s")(df, options \\ []) do
          facet = unquote(facet)
          group = [facet, :year]
          opts = Keyword.validate!(options, default_opts())

          df
          |> frequencies(group, filter: opts[:filter])
          |> create_group_stats(facet)
          |> most_played(opts)
          |> create_facet_stats(df)
        end

        @impl true
        def unquote(:"sample_#{facet}s")(df, options \\ []) do
          facet = unquote(facet)
          opts = Keyword.validate!(options, default_opts())

          df
          |> frequencies([facet], counts: opts[:counts])
          |> sample(rows: opts[:rows])
          |> create_facet_stats(df)
        end

        defoverridable [{:"top_#{facet}s", 2}, {:"sample_#{facet}s", 2}]
      end
    end
  end
end
