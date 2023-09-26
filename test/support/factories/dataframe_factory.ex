defmodule LastfmArchive.DataFrame.Factory do
  @moduledoc false
  alias Explorer.DataFrame
  alias LastfmArchive.Archive.Transformers.Transformer

  # factory for generating scrobbles and facets dataframe
  defmacro __using__(_opts) do
    quote location: :keep do
      require Explorer.DataFrame
      @facets Transformer.facets()

      def dataframe(scrobbles \\ build(:scrobbles))
      def dataframe(:scrobbles), do: dataframe()

      def dataframe(facet) when facet in @facets do
        group = Transformer.facet_transformer_config(facet)[:group]

        dataframe()
        |> DataFrame.select(group ++ [:datetime])
        |> DataFrame.group_by(group)
        |> DataFrame.summarise(first_play: min(datetime), last_play: max(datetime), counts: count(datetime))
        |> DataFrame.distinct(group ++ [:first_play, :last_play, :counts])
      end

      def dataframe(scrobbles) do
        scrobbles
        |> Enum.map(&Map.from_struct/1)
        |> DataFrame.new(lazy: true)
        |> DataFrame.rename(name: "track")
      end
    end
  end
end
