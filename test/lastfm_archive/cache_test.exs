defmodule LastfmArchive.CacheTest do
  use ExUnit.Case

  import Hammox
  alias LastfmArchive.Cache
  alias LastfmArchive.Utils

  @cache :test_cache
  @ticks_before_serialise 2

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    {:ok, _pid} =
      start_supervised(%{id: @cache, start: {Cache, :start_link, [[name: @cache, ticks: @ticks_before_serialise]]}})

    %{user: "a_user", cache: %{{"a_user", 2006} => %{{1_138_752_000, 1_138_838_399} => {33, [:ok]}}}}
  end

  test "init/1 with ticks count and empty state" do
    assert {@ticks_before_serialise, %{}} == :sys.get_state(@cache)
  end

  test "clear/3 state", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)
    [{user, _2006}] = cache |> Map.keys()

    Cache.clear(user, @cache, ticks: 13)
    refute {60, cache} == :sys.get_state(@cache)
    assert {13, %{}} = :sys.get_state(@cache)
  end

  test "load/3 cache from file for a user", %{user: user, cache: cache} do
    cache_file = "#{Utils.user_dir(user)}/#{Cache.cache_dir()}/2006"
    cache_file_regex = Path.join([Utils.user_dir(user), Cache.cache_dir(), Cache.cache_file_regex()])

    LastfmArchive.PathIOMock
    |> expect(:wildcard, fn ^cache_file_regex, [match_dot: true] -> [cache_file] end)

    LastfmArchive.FileIOMock
    |> expect(:read!, fn ^cache_file -> cache[{"a_user", 2006}] |> :erlang.term_to_binary() end)

    assert ^cache = Cache.load("a_user", @cache)
  end

  test "serialise/3 cache to a file", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)
    cache_file = Path.join(Utils.user_dir("a_user"), "#{Cache.cache_dir()}/2006")
    file_binary = cache[{"a_user", 2006}] |> :erlang.term_to_binary()

    LastfmArchive.FileIOMock |> expect(:write, fn ^cache_file, ^file_binary -> :ok end)
    Cache.serialise("a_user", @cache)
  end

  test "get/2 cache for a user year", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)

    assert cache[{"a_user", 2006}] == Cache.get({"a_user", 2006}, @cache)
    assert %{} == Cache.get({"not_exiting_user", 2021}, @cache)
  end

  test "put/5 cache value for a user year" do
    options = []
    assert %{} == Cache.get({"a_user", 2006}, @cache)

    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, options, @cache)
    assert %{{1_138_752_000, 1_138_838_399} => {12_345, [:ok]}} == Cache.get({"a_user", 2006}, @cache)
  end

  test "successive put/5 causing auto-serialisation of cache to file" do
    options = []
    LastfmArchive.FileIOMock |> expect(:write, fn _to_path, _file_binary -> :ok end)

    # put counts > 2 `ticks` configured for the test cache
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, options, @cache)
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, options, @cache)
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, options, @cache)
  end
end
