defmodule LastfmArchive.Utils do
  @moduledoc false

  @data_dir Application.get_env(:lastfm_archive, :data_dir, "./archive_data/")
  @metadata_file ".archive"

  @file_io Application.get_env(:lastfm_archive, :file_io)

  @doc """
  Generate {from, to} daily time ranges for querying Last.fm API based on
  the first and last scrobble unix timestamps.
  """
  def build_time_range({from, to}) do
    from = DateTime.from_unix!(from) |> DateTime.to_date()
    to = DateTime.from_unix!(to) |> DateTime.to_date()
    Enum.map(Date.range(from, to), &iso8601_to_unix("#{&1}T00:00:00Z", "#{&1}T23:59:59Z"))
  end

  def build_time_range(year, %Lastfm.Archive{} = archive) when is_integer(year) do
    {from, to} = iso8601_to_unix("#{year}-01-01T00:00:00Z", "#{year}-12-31T23:59:59Z")
    {registered_time, last_scrobble_time} = archive.temporal

    from = if from <= registered_time, do: registered_time, else: from
    to = if to >= last_scrobble_time, do: last_scrobble_time, else: to

    {from, to}
  end

  defp iso8601_to_unix(from, to) do
    {:ok, from, _} = DateTime.from_iso8601(from)
    {:ok, to, _} = DateTime.from_iso8601(to)

    {DateTime.to_unix(from), DateTime.to_unix(to)}
  end

  def year_range({from, to}) do
    DateTime.from_unix!(from).year..DateTime.from_unix!(to).year
  end

  def data_dir(options \\ []), do: Keyword.get(options, :data_dir, @data_dir)
  def user_dir(user, options \\ []), do: Path.join([data_dir(options), user])
  def metadata(user, options), do: Path.join([data_dir(options), user, @metadata_file])

  def display_progress(archive) do
    IO.puts("Archiving #{archive.extent} scrobbles for #{archive.creator}")
  end

  def display_progress({from, _to}, playcount, pages) do
    from_date = DateTime.from_unix!(from) |> DateTime.to_date()

    IO.puts("\n")
    IO.puts("#{from_date}")
    IO.puts("#{playcount} scrobble(s)")
    IO.puts("#{pages} page(s)")
  end

  def display_skip_message({from, _to}, playcount) do
    from_date = DateTime.from_unix!(from) |> DateTime.to_date()

    IO.puts("\n")
    IO.puts("Skipping #{from_date}, previously synced: #{playcount} scrobble(s)")
  end

  def display_api_error_message({from, _to}, reason) do
    from_date = DateTime.from_unix!(from) |> DateTime.to_date()

    IO.puts("\n")
    IO.puts("Last.fm API error while syncing #{from_date}: #{reason}")
  end

  @doc """
  Read and unzip a file from the archive of a Lastfm user.

  ### Example

  ```
    LastfmArchive.Load.read "a_lastfm_user", "tsv/2007.tsv.gz"
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
end
