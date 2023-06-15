defmodule LastfmArchive.Archive.Metadata do
  @moduledoc """
  Struct representing Lastfm archive metadata.
  """

  use TypedStruct

  @archive Application.compile_env(:lastfm_archive, :type, LastFmArchive.FileArchive)

  @typedoc "Metadata descriping a Lastfm archive based on
  [Dublin Core Metadata Initiative](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/)."
  @derive Jason.Encoder
  typedstruct do
    field(:created, DateTime.t())
    field(:creator, String.t(), enforce: true)
    field(:date, Date.t())
    field(:description, String.t())
    field(:extent, integer())
    field(:format, String.t())
    field(:identifier, String.t())
    field(:modified, nil | DateTime.t())
    field(:source, String.t())
    field(:temporal, {integer, integer})
    field(:title, String.t())
    field(:type, module(), default: @archive)
  end

  @doc """
  Data struct containing new and some default metadata of an archive.

  Other metadata fields such as temporal, modified can be populated
  based on the outcomes of archiving, i.e. the implementation of the
  callbacks of this behaviour.
  """
  @spec new(String.t()) :: t()
  def new(user) when is_binary(user) do
    %__MODULE__{
      created: DateTime.utc_now(),
      creator: user,
      description: "Lastfm archive of #{user}, extracted from Lastfm API",
      format: "application/json",
      identifier: user,
      source: "http://ws.audioscrobbler.com/2.0",
      title: "Lastfm archive of #{user}"
    }
  end

  def new(%{} = decoded_metadata) do
    type = String.to_existing_atom(decoded_metadata.type)
    {created, time_range, date} = parse_dates(decoded_metadata)
    struct(__MODULE__, %{decoded_metadata | type: type, created: created, temporal: time_range, date: date})
  end

  def new(%__MODULE__{} = archive, total, registered_time, last_scrobble_time) do
    %{
      archive
      | temporal: {registered_time, last_scrobble_time},
        extent: total,
        date: last_scrobble_time |> DateTime.from_unix!() |> DateTime.to_date()
    }
  end

  defp parse_dates(%{created: created, date: nil, temporal: nil}) do
    {:ok, created, _} = DateTime.from_iso8601(created)
    {created, nil, nil}
  end

  defp parse_dates(%{created: created, date: date, temporal: temporal}) do
    {:ok, created, _} = DateTime.from_iso8601(created)
    [from, to] = temporal
    date = Date.from_iso8601!(date)

    {created, {from, to}, date}
  end
end
