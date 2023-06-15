defmodule LastfmArchive.Utils do
  @moduledoc false

  alias LastfmArchive.Archive.Metadata
  require Logger

  @data_dir Application.compile_env(:lastfm_archive, :data_dir, "./lastfm_data/")
  @metadata_file ".archive_metadata"

  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @reset Application.compile_env(:lastfm_archive, :reset, false)

  @doc """
  Generate {from, to} daily time ranges for querying Last.fm API based on
  the first and last scrobble unix timestamps.
  """
  def build_time_range({from, to}) do
    from = DateTime.from_unix!(from) |> DateTime.to_date()
    to = DateTime.from_unix!(to) |> DateTime.to_date()
    Enum.map(Date.range(from, to), &iso8601_to_unix("#{&1}T00:00:00Z", "#{&1}T23:59:59Z"))
  end

  def build_time_range(year, %Metadata{} = metadata) when is_integer(year) do
    {from, to} = iso8601_to_unix("#{year}-01-01T00:00:00Z", "#{year}-12-31T23:59:59Z")
    {registered_time, last_scrobble_time} = metadata.temporal

    from = if from <= registered_time, do: registered_time, else: from
    to = if to >= last_scrobble_time, do: last_scrobble_time, else: to

    {from, to}
  end

  defp iso8601_to_unix(from, to) do
    {:ok, from, _} = DateTime.from_iso8601(from)
    {:ok, to, _} = DateTime.from_iso8601(to)

    {DateTime.to_unix(from), DateTime.to_unix(to)}
  end

  def year_range({from, to}), do: DateTime.from_unix!(from).year..DateTime.from_unix!(to).year

  def data_dir(options \\ []), do: Keyword.get(options, :data_dir, @data_dir)
  def user_dir(user, options \\ []), do: Path.join([data_dir(options), user])

  def metadata_filepath(user, options), do: Path.join([data_dir(options), user, @metadata_file])
  def num_pages(playcount, per_page), do: (playcount / per_page) |> :math.ceil() |> round

  # returns 2021/12/31/200_001 type paths
  def page_path(datetime, page, per_page) do
    page_num = page |> to_string() |> String.pad_leading(3, "0")

    datetime
    |> DateTime.from_unix!()
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "/")
    |> Path.join("#{per_page}_#{page_num}")
  end

  def date(from) when is_integer(from), do: DateTime.from_unix!(from) |> Calendar.strftime("%Y-%m-%d")
  def date({from, _day}) when is_integer(from), do: DateTime.from_unix!(from) |> Calendar.strftime("%Y-%m-%d")

  @doc """
  Read and unzip a file from the archive of a Lastfm user.

  ### Example

  ```
    LastfmArchive.Utils.read("a_lastfm_user", "tsv/2007.tsv.gz")
  ```
  """
  def read(user, filename) do
    file_path = Path.join(user_dir(user, []), filename)

    case @file_io.read(file_path) do
      {:ok, gzip_data} ->
        {:ok, gzip_data |> :zlib.gunzip()}

      error ->
        error
    end
  end

  def create_tsv_dir(user) do
    dir = Path.join(user_dir(user, []), "tsv")
    unless @file_io.exists?(dir), do: @file_io.mkdir_p(dir)
    :ok
  end

  @doc """
  Writes archive metadata to a file in the archive of a Lastfm user.
  """
  def write(%Metadata{creator: creator} = metadata, options) when is_list(options) do
    metadata =
      case Keyword.get(options, :reset, @reset) do
        false -> metadata
        true -> %{metadata | created: DateTime.utc_now(), date: nil, modified: nil}
      end

    filepath = metadata_filepath(creator, options)
    filepath |> Path.dirname() |> @file_io.mkdir_p()

    case @file_io.write(filepath, Jason.encode!(metadata)) do
      :ok -> {:ok, metadata}
      error -> error
    end
  end

  @doc """
  Write scrobbles (map) data to a file in the archive of a Lastfm user.
  """
  def write(metadata, scrobbles, options \\ [])

  def write(%Metadata{creator: creator}, scrobbles, options) when is_map(scrobbles) do
    with metadata_filepath <- metadata_filepath(creator, options),
         path <- get_filepath(options) do
      full_path =
        metadata_filepath
        |> Path.dirname()
        |> Path.join("#{path}.gz")

      full_path_dir = Path.dirname(full_path)
      unless @file_io.exists?(full_path_dir), do: @file_io.mkdir_p(full_path_dir)
      @file_io.write(full_path, scrobbles |> Jason.encode!(), [:compressed])
    end
  end

  def write(_metadata, {:error, api_message}, _options), do: {:error, api_message}

  defp get_filepath(options) do
    path = Keyword.get(options, :filepath)
    if path != nil and path != "", do: path, else: raise("please provide a valid :filepath option")
  end
end
