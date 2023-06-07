defmodule LastfmArchive.LivebookTest do
  use ExUnit.Case

  import Hammox

  alias LastfmArchive.Behaviour.LastfmClient
  alias LastfmArchive.Cache
  alias LastfmArchive.Livebook, as: LFM_LB

  @cache :livebooktest_cache

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    {:ok, _pid} = start_supervised(%{id: @cache, start: {Cache, :start_link, [[name: @cache]]}})
    cache = %{{"a_user", 2006} => %{{1_138_752_000, 1_138_838_399} => {33, [:ok]}}}

    stub_with(LastfmClient.impl(), LastfmArchive.LastfmClientStub)
    LastfmArchive.PathIOMock |> stub(:wildcard, fn _, _ -> [".cache_2006"] end)
    LastfmArchive.FileIOMock |> stub(:read!, fn _ -> cache[{"a_user", 2006}] |> :erlang.term_to_binary() end)

    :ok
  end

  test "info/0" do
    assert %Kino.Markdown{} = LFM_LB.info()
  end

  test "monthly_playcounts_heatmap/1" do
    assert %VegaLite{} = LFM_LB.monthly_playcounts_heatmap(@cache)
  end

  test "yearly_playcounts_table/1" do
    assert %Kino.JS.Live{module: Kino.Table} = LFM_LB.yearly_playcounts_table(@cache)
  end

  test "status/0" do
    assert [%{count: 33, date: "2006-02-01"}] == LFM_LB.status(@cache)
  end
end
