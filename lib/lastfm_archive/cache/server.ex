defmodule LastfmArchive.Cache.Server do
  @moduledoc false

  # GenServer storing archiving state to ensure scrobbles are fetched only once.

  use GenServer

  import LastfmArchive.Utils, only: [user_dir: 2]
  import LastfmArchive.Utils.DateTime, only: [date: 1]

  require Logger

  @cache_dir ".cache"
  @cache_file_regex "????"
  @ticks_before_serialise 10

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @path_io Application.compile_env(:lastfm_archive, :path_io, Elixir.Path)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def cache_dir, do: @cache_dir
  def cache_file_regex, do: @cache_file_regex

  @impl true
  def init(opts) do
    {:ok, {Keyword.get(opts, :ticks, @ticks_before_serialise), %{}}}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call({:clear, user, opts}, _from, {ticks, state}) do
    new_state =
      Enum.reject(state, fn {k, _v} ->
        elem(k, 0) == user
      end)
      |> Enum.into(%{})

    {:reply, new_state, {Keyword.get(opts, :ticks, ticks), new_state}}
  end

  @impl true
  def handle_call({:load, user, opts}, _from, {ticks, state}) do
    new_state =
      Path.join([user_dir(user, opts), @cache_dir, @cache_file_regex])
      |> @path_io.wildcard(match_dot: true)
      |> Enum.reduce(state, fn path, acc ->
        merge_cache_in_state(path, user, acc)
      end)

    {:reply, new_state, {ticks, new_state}}
  end

  @impl true
  def handle_call({:serialise, user, opts}, _from, {_ticks, state}) do
    results =
      for {{id, year}, value} <- state, id == user do
        Path.join([user_dir(user, opts), @cache_dir, "#{year}"])
        |> @file_io.write(value |> :erlang.term_to_binary())
      end

    {:reply, results, {@ticks_before_serialise, state}}
  end

  @impl true
  def handle_call({:get, {user, year}}, _from, {ticks, state}) do
    {:reply, Map.get(state, {user, year}, %{}), {ticks, state}}
  end

  @impl true
  def handle_call({:put, {user, year}, {from, to}, value, opts}, _from, {0, state}) do
    cache_file = Path.join([user_dir(user, opts), @cache_dir, "#{year}"])

    :ok = @file_io.write(cache_file, Map.get(state, {user, year}, %{}) |> :erlang.term_to_binary())
    Logger.debug("serialise archiving cache status to #{cache_file}")

    {:reply, :ok, {@ticks_before_serialise, update_state(state, {user, year}, {from, to}, value)}}
  end

  @impl true
  def handle_call({:put, {user, year}, {from, to}, value, _options}, _from, {ticks, state}) do
    {:reply, :ok, {ticks - 1, update_state(state, {user, year}, {from, to}, value)}}
  end

  defp update_state(state, {user, year}, {from, to}, value) do
    Logger.debug("caching archive status #{date(from)}, #{inspect(value)}")

    case state[{user, year}] do
      cache when is_map(cache) ->
        update_in(state, [{user, year}, {from, to}], &(&1 = value))

      nil ->
        Map.merge(state, %{{user, year} => %{{from, to} => value}})
    end
  end

  defp merge_cache_in_state(path, user, state) do
    cache_data = @file_io.read!(path) |> :erlang.binary_to_term()
    year = Path.basename(path) |> String.to_integer()
    Map.merge(state, %{{user, year} => cache_data})
  end
end
