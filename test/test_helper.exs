ExUnit.start()

defmodule TestHelpers do
  import ExUnit.Assertions

  def check_resp({_status, %{"error" => _, "links" => _, "message" => message}}) do
    assert message != "User not found"
  end

  def check_resp({:ok, %{"recenttracks" => %{"@attr" => info, "track" => tracks}}}) do
    assert length(tracks) > 0
    assert info["total"] > 0
    assert info["user"] == Application.get_env(:lastfm_archive, :user)
  end

  def check_resp({playcount, registered}) do
    assert playcount > 0
    assert registered > 0
  end
end
