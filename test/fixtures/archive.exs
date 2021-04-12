defmodule Fixtures.Archive do
  alias Lastfm.Archive

  @default_user Application.get_env(:lastfm_archive, :user)
  @registered_time DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
  @latest_scrobble_time DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

  def test_file_archive(), do: test_archive(@default_user)
  def test_file_archive(@default_user), do: test_archive(@default_user)

  def test_file_archive(user), do: Archive.new(user)
  def test_file_archive(user, created_datetime), do: %{Archive.new(user) | created: created_datetime}

  defp test_archive(user) do
    %{
      Lastfm.Archive.new(user)
      | temporal: {@registered_time, @latest_scrobble_time},
        extent: 400,
        date: ~D[2021-04-03],
        type: FileArchive
    }
  end
end
