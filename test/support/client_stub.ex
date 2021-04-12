defmodule Lastfm.ClientStub do
  @behaviour Lastfm.Client

  def info(_user, _api), do: {400, 0}
  def playcount(_user, _time_range, _api), do: {13, 0}
  def scrobbles(_user, _page_params, _api), do: %{}
end
