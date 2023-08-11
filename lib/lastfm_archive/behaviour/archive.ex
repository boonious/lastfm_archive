defmodule LastfmArchive.Behaviour.Archive do
  @moduledoc """
  Behaviour of a Lastfm archive.

  An archive contains transformed or scrobbles data retrieved from Lastfm API.
  It can be based upon various storage implementation such as file systems and
  databases.
  """

  @type api :: LastfmArchive.LastfmClient.LastfmApi.t()
  @type metadata :: LastfmArchive.Archive.Metadata.t()

  @type scrobbles :: map()
  @type transformer :: module()
  @type user :: binary()

  @type options :: keyword()

  @doc """
  Archives all scrobbles data for a Lastfm user.

  Optional for post-hoc archives that are based on existing
  local archive such as CSV, Parquet archives.
  """
  @callback archive(metadata(), options(), api()) :: {:ok, metadata()} | {:error, term()}

  @doc """
  Returns metadata of an existing archive.
  """
  @callback describe(user(), options()) :: {:ok, metadata()} | {:error, term()}

  @doc """
  Optionally applies post-archive side effects such as archive transformation or loading.
  """
  @callback after_archive(metadata(), transformer(), options()) :: {:ok, metadata()} | {:error, term()}

  @doc """
  Read access to the archive, returns an Explorer DataFrame for further data manipulation.
  """
  @callback read(metadata(), options()) :: {:ok, Explorer.DataFrame.t()} | {:error, term()}

  @doc """
  Writes latest metadata to file.
  """
  @callback update_metadata(metadata(), options) :: {:ok, metadata()} | {:error, term()}

  @optional_callbacks archive: 3, after_archive: 3

  defmacro __using__(_opts) do
    quote do
      @behaviour LastfmArchive.Behaviour.Archive

      import LastfmArchive.Behaviour.Archive
      import LastfmArchive.Utils

      alias LastfmArchive.Archive.Metadata

      @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

      @impl true
      def update_metadata(%Metadata{creator: user} = metadata, options)
          when user != nil and is_binary(user) do
        write(metadata, options)
      end

      @impl true
      def describe(user, options \\ []) do
        case @file_io.read(metadata_filepath(user, options)) do
          {:ok, metadata} -> {:ok, Jason.decode!(metadata, keys: :atoms!) |> Metadata.new()}
          {:error, :enoent} -> {:ok, Metadata.new(user, options)}
        end
      end

      defoverridable update_metadata: 2, describe: 2
    end
  end

  @doc false
  def impl(type \\ :file_archive)
  def impl(:file_archive), do: Application.get_env(:lastfm_archive, :file_archive, LastfmArchive.Archive.FileArchive)

  def impl(:derived_archive) do
    Application.get_env(:lastfm_archive, :derived_archive, LastfmArchive.Archive.DerivedArchive)
  end
end

defimpl Jason.Encoder, for: Tuple do
  def encode(data, options) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> Jason.Encoder.List.encode(options)
  end
end
