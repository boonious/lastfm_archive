defmodule LastfmArchive do
  @moduledoc """
  Documentation for LastfmArchive.
  """

  import Elixirfm.User

  @default_data_dir "./lastfm_data/"

  @doc """
  """
  @spec extract :: Elixirfm.response
  def extract, do: extract(Application.get_env(:lastfm_archive, :user))

  @doc """
  """
  @spec extract(binary, integer, integer) :: Elixirfm.response
  def extract(user, page \\ 1, limit \\ 1)
  def extract(user, page, limit), do: get_recent_tracks(user, limit: limit, page: page, extended: 1)

  @spec write(binary, binary, binary) :: :ok | {:error, :file.posix}
  def write(data, filename \\ "1", type \\ "file")
  def write(data, filename, type) when is_binary(data), do: _write(data, filename, type)

  defp _write(data, filename, "file") do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user = Application.get_env(:lastfm_archive, :user) || ""
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    unless File.exists?(user_data_dir), do: File.mkdir_p user_data_dir

    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    File.write file_path, data, [:compressed]
  end

  # find out more about the user (playcount, earliest scrobbles)
  # to determine data extraction strategy
  def info(user) do
    {_status, resp} = get_info(user)

    playcount = resp["user"]["playcount"]
    registered = resp["user"]["registered"]["unixtime"]

    {playcount, registered}
  end

end
