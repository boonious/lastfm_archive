defmodule LastfmArchive.Extract do
  @moduledoc """
  This module provides functions that interact with Lastfm API for data extraction and storage.

  """

  @type lastfm_response :: {:ok, map} | {:error, binary, Hui.Error.t()}
  @default_data_dir "./lastfm_data/"

  @doc """
  Write binary data or Lastfm response to a configured directory on local filesystem for a Lastfm user.

  The data is compressed, encoded and stored in a file of given `filename`
  within the data directory, e.g. `./lastfm_data/user/` as configured
  below:

  ```
  config :lastfm_archive,
    ...
    data_dir: "./lastfm_data/"
  ```
  """
  @spec write(binary, map, binary) :: :ok | {:error, :file.posix()}
  def write(user, data, filename \\ "1")

  def write(user, data, filename) when is_map(data), do: _write(user, data |> Jason.encode!(), filename)
  def write(user, data, filename) when is_binary(data), do: _write(user, data, filename)

  defp _write(user, data, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join("#{data_dir}", "#{user}")
    unless File.exists?(user_data_dir), do: File.mkdir_p(user_data_dir)

    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    file_dir = Path.dirname(file_path)
    unless File.exists?(file_dir), do: File.mkdir_p(file_dir)

    File.write(file_path, data, [:compressed])
  end
end
