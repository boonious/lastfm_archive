defmodule LastfmArchive.Archive.Transformers.FacetsTransformerTest do
  use ExUnit.Case, async: true

  alias Explorer.DataFrame
  alias Explorer.Series

  alias LastfmArchive.Archive.Transformers.FacetsTransformer
  alias LastfmArchive.Archive.Transformers.Transformer

  import Hammox
  import LastfmArchive.Factory, only: [build: 1, build: 2, dataframe: 1]

  setup :verify_on_exit!

  setup_all do
    {track1, track2} = {build(:scrobble) |> Map.from_struct(), build(:scrobble) |> Map.from_struct()}

    scrobbles =
      build(:scrobbles, track1 |> Map.merge(%{num_of_plays: 3})) ++
        build(:scrobbles, track2 |> Map.merge(%{num_of_plays: 3}))

    %{dataframe: dataframe(scrobbles), tracks: [track1, track2]}
  end

  describe "transform/2" do
    for facet <- Transformer.facets(), facet != :scrobbles do
      @facet_settings Transformer.facet_transformers_settings()

      test "scrobbles into #{facet} facets", %{dataframe: df, tracks: tracks} do
        facet = unquote(facet)
        group = @facet_settings[facet][:group]
        assert %DataFrame{} = facets = FacetsTransformer.transform(df, facet: facet)

        facets = facets |> DataFrame.collect()
        cols = facets |> DataFrame.names()
        facet = "#{facet}" |> String.trim_trailing("s")

        for col <- group, do: assert("#{col}" in cols)
        assert "first_play" in cols
        assert "last_play" in cols
        assert "counts" in cols

        # 2 facets (tracks, albums or artists), 3 plays each
        assert facets |> DataFrame.n_rows() == 2
        assert facets["counts"] |> Series.to_list() |> Enum.sum() == 6

        facet_values = facets[facet] |> Series.to_list()

        for track <- tracks do
          value = track[:"#{facet}"] || track[:name]
          assert value in facet_values
        end
      end
    end
  end
end
