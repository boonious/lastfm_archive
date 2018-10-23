defmodule LastfmArchiveTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import TestHelpers

  doctest LastfmArchive

  @test_data_dir Path.join([".", "lastfm_data", "test", "archive"])

  # testing with Bypass
  setup do
    lastfm_ws = Application.get_env :elixirfm, :lastfm_ws
    configured_dir = Application.get_env :lastfm_archive, :data_dir

    # true if mix test --include integration
    is_integration = :integration in ExUnit.configuration[:include]
    bypass = unless is_integration, do: Bypass.open, else: nil

    on_exit fn ->
      Application.put_env :elixirfm, :lastfm_ws, lastfm_ws
      Application.put_env :lastfm_archive, :data_dir, configured_dir
    end

    [bypass: bypass]
  end

  test "archive scrobbles of a specific user - archive/2", %{bypass: bypass} do
    # Bypass test only
    if(bypass) do
      user = "a_lastfm_user"
      test_bypass_conn_params_archive(bypass, Path.join(@test_data_dir, "1"), user)
      capture_io(fn -> LastfmArchive.archive(user, 0) end)
    end
  after
    File.rm_rf Path.join(@test_data_dir, "1")
  end

end
