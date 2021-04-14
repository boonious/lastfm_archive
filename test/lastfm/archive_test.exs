defmodule Lastfm.ArchiveTest do
  use ExUnit.Case, async: true

  test "new/1 returns expected archive metadata " do
    assert %{
             creator: "a_lastfm_user",
             created: %{__struct__: DateTime},
             description: "Lastfm archive of a_lastfm_user, extracted from Lastfm API",
             format: "application/json",
             identifier: "a_lastfm_user",
             source: "http://ws.audioscrobbler.com/2.0",
             title: "Lastfm archive of a_lastfm_user"
           } = Lastfm.Archive.new("a_lastfm_user")
  end
end
