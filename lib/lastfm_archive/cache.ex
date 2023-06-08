defmodule LastfmArchive.Cache do
  @moduledoc """
  GenServer storing archiving state to ensure scrobbles are fetched only once.
  """

  use GenServer
  alias LastfmArchive.Utils
  require Logger

  @cache_file_prefix ".cache_"
  @cache_file_wildcard @cache_file_prefix <> "????"
  @ticks_before_serialise 10

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @path_io Application.compile_env(:lastfm_archive, :path_io, Elixir.Path)

  @type user :: binary()
  @type year :: integer()
  @type start_of_day :: integer()
  @type end_of_day :: integer()

  @callback get({user, year}, GenServer.server()) :: map()
  @callback load(user, GenServer.server(), keyword) :: map()
  @callback put({user, year}, {start_of_day, end_of_day}, tuple, GenServer.server()) :: :ok
  @callback serialise(user, GenServer.server(), keyword) :: term

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @spec state() :: map()
  def state(), do: state(__MODULE__)

  @spec state(GenServer.server()) :: map()
  def state(server), do: GenServer.call(server, :state)

  @spec reset(GenServer.server(), keyword) :: :ok
  def reset(server \\ __MODULE__, options \\ []), do: GenServer.call(server, {:reset, options})

  @spec clear(binary, GenServer.server(), keyword) :: map()
  def clear(user, server \\ __MODULE__, options), do: GenServer.call(server, {:clear, user, options})

  def load(user, server \\ __MODULE__, options \\ []), do: GenServer.call(server, {:load, user, options})

  def serialise(user, server \\ __MODULE__, options \\ []), do: GenServer.call(server, {:serialise, user, options})

  def get(key, server \\ __MODULE__)
  def get({user, year}, server), do: GenServer.call(server, {:get, {user, year}})

  def put({user, year}, {from, to}, value, server \\ __MODULE__) do
    GenServer.call(server, {:put, {user, year}, {from, to}, value})
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    {:ok, {Keyword.get(opts, :ticks, @ticks_before_serialise), %{}}}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call({:reset, opts}, _from, _state) do
    {:reply, :ok, {Keyword.get(opts, :ticks, @ticks_before_serialise), %{}}}
  end

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
  def handle_call({:load, user, options}, _from, {ticks, state}) do
    new_state =
      Path.join(Utils.user_dir(user, options), @cache_file_wildcard)
      |> @path_io.wildcard(match_dot: true)
      |> Enum.reduce(state, fn path, acc -> merge_cache_in_state(path, user, acc) end)

    {:reply, new_state, {ticks, new_state}}
  end

  @impl true
  def handle_call({:serialise, user, options}, _from, {_ticks, state}) do
    results =
      for {{id, year}, value} <- state, id == user do
        Path.join([Utils.user_dir(user, options), "#{@cache_file_prefix}#{year}"])
        |> @file_io.write(value |> :erlang.term_to_binary())
      end

    {:reply, results, {@ticks_before_serialise, state}}
  end

  @impl true
  def handle_call({:get, {user, year}}, _from, {ticks, state}) do
    {:reply, Map.get(state, {user, year}, %{}), {ticks, state}}
  end

  @impl true
  def handle_call({:put, {user, year}, {from, to}, value}, _from, {0, state}) do
    path = Path.join([Utils.user_dir(user, []), "#{@cache_file_prefix}#{year}"])

    @file_io.write(
      path,
      Map.get(state, {user, year}, %{}) |> :erlang.term_to_binary()
    )

    Logger.debug("serialise archiving cache status to #{path}")

    {:reply, :ok, {@ticks_before_serialise, update_state(state, {user, year}, {from, to}, value)}}
  end

  @impl true
  def handle_call({:put, {user, year}, {from, to}, value}, _from, {ticks, state}) do
    {:reply, :ok, {ticks - 1, update_state(state, {user, year}, {from, to}, value)}}
  end

  defp update_state(state, {user, year}, {from, to}, value) do
    Logger.debug("caching archive status #{Utils.date(from)}, #{inspect(value)}")

    case state[{user, year}] do
      cache when is_map(cache) ->
        update_in(state, [{user, year}, {from, to}], &(&1 = value))

      nil ->
        Map.merge(state, %{{user, year} => %{{from, to} => value}})
    end
  end

  defp merge_cache_in_state(path, user, state) do
    cache_data = @file_io.read!(path) |> :erlang.binary_to_term()
    year = Path.basename(path) |> cache_year()
    Map.merge(state, %{{user, year} => cache_data})
  end

  defp cache_year(@cache_file_prefix <> year), do: year |> String.to_integer()
end
