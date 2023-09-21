defmodule LastfmArchive.LivebookTest do
  use ExUnit.Case

  import Hammox

  alias LastfmArchive.Behaviour.LastfmClient
  alias LastfmArchive.Cache
  alias LastfmArchive.Cache.Server, as: CacheServer
  alias LastfmArchive.Livebook, as: LFM_LB
  alias LastfmArchive.Utils

  @cache :livebooktest_cache

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    {:ok, _pid} = start_supervised(%{id: @cache, start: {CacheServer, :start_link, [[name: @cache]]}})
    cache = %{{"a_user", 2006} => %{{1_138_752_000, 1_138_838_399} => {33, [:ok]}}}

    cache_file = "#{Utils.user_dir("a_user")}/#{Cache.cache_dir()}/2006"
    stub_with(LastfmClient.impl(), LastfmArchive.LastfmClientStub)
    LastfmArchive.PathIOMock |> stub(:wildcard, fn _, _ -> [cache_file] end)
    LastfmArchive.FileIOMock |> stub(:read!, fn _ -> cache[{"a_user", 2006}] |> :erlang.term_to_binary() end)

    :ok
  end

  test "info/0" do
    assert %Kino.Markdown{} = LFM_LB.info()
  end

  test "render_playcounts_heatmaps/1" do
    assert :ok = LFM_LB.render_playcounts_heatmaps("a_lastfm_user", [], @cache)
  end
end
