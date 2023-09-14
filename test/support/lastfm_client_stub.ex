defmodule LastfmArchive.LastfmClientStub do
  @moduledoc false
  @behaviour LastfmArchive.Behaviour.LastfmClient
  import Fixtures.Lastfm, only: [recent_tracks: 2]

  @registered_time DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
  @latest_scrobble_time DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

  def info(_user, _api), do: {:ok, {400, @registered_time}}
  def playcount(_user, _time_range, _api), do: {:ok, {13, @latest_scrobble_time}}
  def scrobbles(user, _page_params, _api), do: {:ok, recent_tracks(user, 5) |> Jason.decode!()}
end
