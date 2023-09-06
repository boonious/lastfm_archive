defmodule LastfmArchive.Cache do
  @moduledoc false
  @behaviour LastfmArchive.Behaviour.Cache
  alias LastfmArchive.Cache.Server, as: CacheServer

  def clear(user, server \\ CacheServer, options), do: GenServer.call(server, {:clear, user, options})

  defdelegate cache_dir, to: CacheServer
  defdelegate cache_file_regex, to: CacheServer

  @impl true
  def get({user, year}, server \\ CacheServer), do: GenServer.call(server, {:get, {user, year}})

  @impl true
  def load(user, server \\ CacheServer, options \\ []), do: GenServer.call(server, {:load, user, options})

  @impl true
  def put({user, year}, {from, to}, value, options, server \\ CacheServer) do
    GenServer.call(server, {:put, {user, year}, {from, to}, value, options})
  end

  @impl true
  def serialise(user, server \\ CacheServer, options \\ []), do: GenServer.call(server, {:serialise, user, options})
end
