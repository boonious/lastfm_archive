defmodule LastfmArchive.Behaviour.Cache do
  @moduledoc false

  @type user :: binary()
  @type year :: integer()

  @type start_of_day_time :: integer()
  @type end_of_day_time :: integer()
  @type day :: {start_of_day_time, end_of_day_time}

  @type playcount :: integer()
  @type download_statuses :: list(:ok | {:error, term()})
  @type cache_value :: {playcount(), download_statuses()}

  @type options :: keyword()

  @callback get({user, year}, GenServer.server()) :: map()
  @callback load(user, GenServer.server(), keyword) :: map()
  @callback put({user, year}, day, cache_value, options, GenServer.server()) :: :ok
  @callback serialise(user, GenServer.server(), keyword) :: term
end
