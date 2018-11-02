defmodule LastfmArchive.Transform do
  @moduledoc """
  This module provides functions for reading and transforming the Lastfm data in archive

  """

  @default_data_dir "./lastfm_data/"

  @spec read(binary, binary) :: {:ok, map} | {:error, :file.posix}
  def read(user, filename \\ "1") do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join data_dir, user
    file_path = Path.join user_data_dir, filename

    {status, file_io} = File.open(file_path, [:read, :compressed, :utf8])

    resp = case status do
      :ok ->
        {:ok, IO.read(file_io, :line) |> Poison.decode!}
      :error ->
        {:error, file_io}
    end

    if is_pid(file_io), do: File.close(file_io)
    resp
  end

end
