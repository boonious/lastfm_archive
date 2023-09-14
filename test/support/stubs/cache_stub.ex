defmodule LastfmArchive.CacheStub do
  @moduledoc false

  @behaviour LastfmArchive.Behaviour.Cache

  def load(_user, _cache, _options), do: %{}
  def put({_user, _year}, {_from, _to}, _value, _options, _cache), do: :ok
  def serialise(_user, _cache, _options), do: :ok
  def get({_user, _year}, _cache), do: %{}
end
