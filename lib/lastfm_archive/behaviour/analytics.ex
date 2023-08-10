defmodule LastfmArchive.Behaviour.Analytics do
  @moduledoc """
  Behaviour, macro and functions for Explorer.DataFrame analytics
  """

  alias Explorer.DataFrame
  import LastfmArchive.Analytics.Settings

  @type data_frame :: DataFrame.t()
  @type group :: DataFrame.column_name() | DataFrame.column_names()
  @type options :: Keyword.t()

  @type top_facets :: DataFrame.t()
  @type top_facets_stats :: map()

  @type facets :: {top_facets(), top_facets_stats()}

  @callback data_frame(format: atom()) :: {:ok, data_frame()} | {:error, term}

  for facet <- available_facets() do
    @callback unquote(:"top_#{facet}s")(data_frame(), options()) :: facets()
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LastfmArchive.Behaviour.Analytics

      import LastfmArchive.Analytics.Commons,
        only: [frequencies: 2, create_group_stats: 2, create_facet_stats: 2, most_played: 2]

      for facet <- Keyword.fetch!(opts, :facets) do
        @impl true
        def unquote(:"top_#{facet}s")(df, options \\ []) do
          facet = if unquote(facet) == :track, do: :name, else: unquote(facet)
          group = [facet, :year]
          rows = Keyword.get(options, :rows, 5)

          df
          |> frequencies(group)
          |> create_group_stats(facet)
          |> most_played(rows)
          |> create_facet_stats(df)
        end

        defoverridable [{:"top_#{facet}s", 2}]
      end
    end
  end
end
