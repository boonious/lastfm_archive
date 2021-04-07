defmodule Lastfm.Archive do
  @moduledoc """
  A behaviour module for implementing a Lastfm archive.

  The module also provides a struct that keeps metadata about the archive.
  An archive contains scrobbles data retrieved from Lastfm API. It can be based
  upon various storage implementation such as file systems and databases.
  """

  @archive Application.get_env(:lastfm_archive, :type, LastFm.FileArchive)

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

  @type archive_id :: binary()
  @type options :: keyword()
  @type lastfm_user :: binary()
  @type scrobbles :: map()

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
          modified: DateTime.t(),
          source: binary(),
          temporal: {integer, integer},
          title: binary(),
          type: atom()
        }

  @doc """
  Creates a new and empty archive and records metadata.
  """
  @callback create(t(), options) :: {:ok, t()} | {:error, term()}

  @doc """
  Describes the status of an existing archive.
  """
  @callback describe(archive_id, options) :: {:ok, t()} | {:error, term()}

  @doc """
  Write scrobbles data to an existing archive.
  """
  @callback write(t(), scrobbles, options) :: :ok | {:error, term()}

  @doc """
  Data struct containing new and some default metadata of an archive.

  Other metadata fields such as temporal, modified can be populated
  based on the outcomes of archiving, i.e. the implementation of the
  callbacks of this behaviour.
  """
  @spec new(lastfm_user) :: t()
  def new(lastfm_user) do
    %__MODULE__{
      created: DateTime.utc_now(),
      creator: lastfm_user,
      description: "Lastfm archive of #{lastfm_user}, extracted from Lastfm API",
      format: "application/json",
      identifier: lastfm_user,
      source: "http://ws.audioscrobbler.com/2.0",
      title: "Lastfm archive of #{lastfm_user}",
      type: @archive
    }
  end
end

defimpl Jason.Encoder, for: Tuple do
  def encode(data, options) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> Jason.Encoder.List.encode(options)
  end
end
