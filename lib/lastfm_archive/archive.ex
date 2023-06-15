defmodule LastfmArchive.Archive do
  @moduledoc """
  Struct representing Lastfm archive metadata.
  """

  @archive Application.compile_env(:lastfm_archive, :type, LastFmArchive.FileArchive)

  @derive Jason.Encoder
  @enforce_keys [:creator]
  defstruct [
    :created,
    :creator,
    :date,
    :description,
    :extent,
    :format,
    :identifier,
    :modified,
    :source,
    :temporal,
    :title,
    :type
  ]

  @typedoc """
  Metadata descriping a Lastfm archive based on
  [Dublin Core Metadata Initiative](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/).
  """
  @type t :: %__MODULE__{
          created: DateTime.t(),
          creator: binary(),
          date: Date.t(),
          description: binary(),
          extent: integer(),
          format: binary(),
          identifier: binary(),
          modified: nil | DateTime.t(),
          source: binary(),
          temporal: {integer, integer},
          title: binary(),
          type: atom()
        }

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
      title: "Lastfm archive of #{user}",
      type: @archive
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
