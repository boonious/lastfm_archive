defmodule LastfmArchive.Behaviour.Archive do
  @moduledoc """
  Behaviour of a Lastfm archive.

  An archive contains scrobbles data retrieved from Lastfm API. It can be based
  upon various storage implementation such as file systems and databases.
  """

  @type client :: LastfmArchive.LastfmClient.t()
  @type metadata :: LastfmArchive.Archive.t()
  @type options :: keyword()
  @type user :: binary()
  @type scrobbles :: map()

  @doc """
  Writes latest metadata to file.
  """
  @callback update_metadata(metadata(), options) :: {:ok, metadata()} | {:error, term()}

  @doc """
  Returns metadata of an existing archive.
  """
  @callback describe(user, options) :: {:ok, metadata()} | {:error, term()}

  @doc """
  Archives all scrobbles data for a Lastfm user.
  """
  @callback archive(metadata(), options, client) :: {:ok, metadata()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour LastfmArchive.Behaviour.Archive

      import LastfmArchive.Behaviour.Archive
      import LastfmArchive.Utils

      @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)

      def update_metadata(%LastfmArchive.Archive{creator: user} = metadata, options)
          when user != nil and is_binary(user) do
        write(metadata, options)
      end

      def describe(user, options \\ []) do
        case @file_io.read(metadata_filepath(user, options)) do
          {:ok, data} -> {:ok, Jason.decode!(data, keys: :atoms!) |> LastfmArchive.Archive.new()}
          {:error, :enoent} -> {:ok, LastfmArchive.Archive.new(user)}
        end
      end

      defoverridable update_metadata: 2, describe: 2
    end
  end

  @doc false
  def impl, do: Application.get_env(:lastfm_archive, :type, LastfmArchive.FileArchive)
end

defimpl Jason.Encoder, for: Tuple do
  def encode(data, options) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> Jason.Encoder.List.encode(options)
  end
end
