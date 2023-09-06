defmodule LastfmArchive.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [LastfmArchive.Cache.Server]

    opts = [strategy: :one_for_one, name: LastfmArchive.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
