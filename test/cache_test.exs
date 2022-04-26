defmodule LastfmArchive.CacheTest do
  use ExUnit.Case

  import Mox
  alias LastfmArchive.Cache

  @cache :test_cache
  @ticks_before_serialise 2

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    {:ok, _pid} =
      start_supervised(%{id: @cache, start: {Cache, :start_link, [[name: @cache, ticks: @ticks_before_serialise]]}})

    %{cache: %{{"a_user", 2006} => %{{1_138_752_000, 1_138_838_399} => {33, [:ok]}}}}
  end

  test "init/1 with ticks count and empty state" do
    assert {@ticks_before_serialise, %{}} == Cache.state(@cache)
  end

  test "state/0 returns current state of app cache" do
    assert {60, %{}} == Cache.state()
  end

  test "state/1 returns current state", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)
    assert {60, ^cache} = Cache.state(@cache)
  end

  test "reset/2 state", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)

    Cache.reset(@cache, ticks: 13)
    refute {60, cache} == Cache.state(@cache)
    assert {13, %{}} == Cache.state(@cache)
  end

  test "clear/3 state", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)
    [{user, _2006}] = cache |> Map.keys()

    Cache.clear(user, @cache, ticks: 13)
    refute {60, cache} == Cache.state(@cache)
    assert {13, %{}} = Cache.state(@cache)
  end

  test "load/3 cache from file for a user", %{cache: cache} do
    Lastfm.PathIOMock |> expect(:wildcard, fn _, _ -> [".cache_2006"] end)

    Lastfm.FileIOMock
    |> expect(:read!, fn _ -> cache[{"a_user", 2006}] |> :erlang.term_to_binary() end)

    assert ^cache = Cache.load("a_user", @cache)
  end

  test "serialise/3 cache to a file", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)
    file_binary = cache[{"a_user", 2006}] |> :erlang.term_to_binary()
    to_path = Path.join([Application.get_env(:lastfm_archive, :data_dir), "a_user", ".cache_2006"])

    Lastfm.FileIOMock
    |> expect(:write, fn ^to_path, ^file_binary -> :ok end)

    Cache.serialise("a_user", @cache)
  end

  test "get/2 cache for a user year", %{cache: cache} do
    :sys.replace_state(@cache, fn _state -> {60, cache} end)

    assert cache[{"a_user", 2006}] == Cache.get({"a_user", 2006}, @cache)
    assert %{} == Cache.get({"not_exiting_user", 2021}, @cache)
  end

  test "put/4 cache value for a user year" do
    assert %{} == Cache.get({"a_user", 2006}, @cache)

    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, @cache)
    assert %{{1_138_752_000, 1_138_838_399} => {12_345, [:ok]}} == Cache.get({"a_user", 2006}, @cache)
  end

  test "successive put/4 causing auto-serialisation of cache to file" do
    Lastfm.FileIOMock |> expect(:write, fn _to_path, _file_binary -> :ok end)

    # put counts > 2 `ticks` configured for the test cache
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, @cache)
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, @cache)
    Cache.put({"a_user", 2006}, {1_138_752_000, 1_138_838_399}, {12_345, [:ok]}, @cache)
  end
end
