defmodule LastfmArchiveTest do
  use ExUnit.Case

  import Hammox

  alias LastfmArchive.Archive
  alias LastfmArchive.FileArchive

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    total_scrobbles = 400
    registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    last_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

    metadata = %{
      Archive.new("a_lastfm_user")
      | temporal: {registered_time, last_scrobble_time},
        extent: total_scrobbles,
        date: ~D[2021-04-03],
        type: FileArchive
    }

    %{user: "a_lastfm_user", metadata: metadata}
  end

  test "sync scrobbles to a new file archive", %{metadata: metadata} do
    user = Application.get_env(:lastfm_archive, :user)

    LastfmArchive.FileArchiveMock
    |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
    |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

    LastfmArchive.sync()
  end

  test "sync/2 scrobbles to a new file archive", %{user: user, metadata: metadata} do
    LastfmArchive.FileArchiveMock
    |> expect(:describe, fn ^user, _options -> {:ok, metadata} end)
    |> expect(:archive, fn ^metadata, _options, _api_client -> {:ok, metadata} end)

    LastfmArchive.sync(user)
  end
end
