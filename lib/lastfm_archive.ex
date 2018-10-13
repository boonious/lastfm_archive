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
  @spec extract(binary) :: Elixirfm.response
  def extract(user), do: get_recent_tracks(user)

  @spec write(binary, binary) :: :ok | {:error, :file.posix}
  def write(data, type \\ "file")
  def write(data, type) when is_binary(data), do: _write(data, type)

  defp _write(data, "file") do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user = Application.get_env(:lastfm_archive, :user) || ""
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    unless File.exists?(user_data_dir), do: File.mkdir_p user_data_dir

    file_path = "#{user_data_dir}/1.gz"
    File.write file_path, data, [:compressed]
  end

end
