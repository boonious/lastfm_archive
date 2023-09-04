defmodule LastfmArchive.Utils do
  @moduledoc false

  alias Explorer.DataFrame
  alias LastfmArchive.Archive.Metadata
  require Logger

  @data_dir Application.compile_env(:lastfm_archive, :data_dir, "./lastfm_data/")
  @file_io Application.compile_env(:lastfm_archive, :file_io, Elixir.File)
  @path_io Application.compile_env(:lastfm_archive, :path_io, Elixir.Path)
  @reset Application.compile_env(:lastfm_archive, :reset, false)

  def data_dir(options \\ []), do: Keyword.get(options, :data_dir, @data_dir)
  def user_dir(user, options \\ []), do: Path.join([data_dir(options), user])

  def metadata_filepath(user, options \\ []) do
    Path.join([
      data_dir(options),
      user,
      ".metadata/#{Keyword.get(options, :facet, "scrobbles")}/#{Keyword.get(options, :format, "json")}_archive"
    ])
  end

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

  @doc """
  Read and unzip a file from the archive of a Lastfm user.

  ### Example

  ```
    LastfmArchive.Utils.read("a_lastfm_user", "csv/2007.csv.gz")
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

  def maybe_create_dir(user, dir: dir) do
    dir = Path.join(user_dir(user, []), dir)
    unless @file_io.exists?(dir), do: @file_io.mkdir_p(dir)
    :ok
  end

  def check_filepath(user, :csv, path), do: check_filepath(user, path <> ".gz")
  def check_filepath(user, _format, path), do: check_filepath(user, path)

  def check_filepath(user, path) do
    filepath = Path.join([user_dir(user), path])

    case @file_io.exists?(filepath) do
      false -> {:ok, filepath}
      true -> {:error, :file_exists, filepath}
    end
  end

  @spec ls_archive_files(String.t(), day: Date.t(), month: Date.t()) :: list(String.t())
  def ls_archive_files(user, day: date) do
    day = date |> to_string() |> String.replace("-", "/")

    for file <- "#{user_dir(user)}/#{day}" |> @file_io.ls!(), String.ends_with?(file, ".gz") do
      day <> "/" <> file
    end
  end

  def ls_archive_files(user, month: date) do
    month = date.month |> to_string() |> String.pad_leading(2, "0")

    Path.join(user_dir(user), "#{date.year}/#{month}/**/*.gz")
    |> @path_io.wildcard([])
    |> Enum.map(&get_date_filepath(&1, user))
  end

  # from "lastfm_data/user/2023/06/06/200_001.gz" -> "2023/06/06/200_001.gz"
  defp get_date_filepath(path, user), do: String.split(path, user <> "/") |> List.last()

  @doc """
  Writes data frame or metadata to a file given a write function or options.
  """
  def write(%DataFrame{} = dataframe, write_fun), do: :ok = dataframe |> write_fun.()

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

  def write(%Metadata{creator: creator}, scrobbles, options) when is_map(scrobbles) do
    full_path =
      Keyword.fetch!(options, :filepath)
      |> then(fn path -> user_dir(creator, options) |> Path.join("#{path}.gz") end)

    full_path_dir = Path.dirname(full_path)
    unless @file_io.exists?(full_path_dir), do: @file_io.mkdir_p(full_path_dir)
    @file_io.write(full_path, scrobbles |> Jason.encode!(), [:compressed])
  end

  def write(_metadata, {:error, api_message}, _options), do: {:error, api_message}
end
