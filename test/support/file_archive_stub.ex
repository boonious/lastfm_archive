defmodule Lastfm.FileArchiveStub do
  @moduledoc false

  @behaviour Lastfm.Archive

  @default_user Application.compile_env(:lastfm_archive, :user)

  def describe(@default_user, _options), do: {:ok, test_archive(@default_user)}
  def describe(_user, _options), do: {:ok, Lastfm.Archive.new("a_lastfm_user")}

  def update_metadata(%{creator: @default_user} = _archive, _options), do: {:ok, test_archive(@default_user)}
  def update_metadata(_archive, _options), do: {:ok, Lastfm.Archive.new("a_lastfm_user")}

  def write(_archive, _scrobbles, _options), do: :ok

  defp test_archive(user) do
    registered_time = DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    last_scrobble_time = DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

    %{
      Lastfm.Archive.new(user)
      | temporal: {registered_time, last_scrobble_time},
        extent: 400,
        date: ~D[2021-04-03],
        type: FileArchive
    }
  end
end
