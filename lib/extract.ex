defmodule LastfmArchive.Extract do
  @moduledoc """
  This module provides functions that interact with Lastfm API for data extraction and storage.

  """

  # pending, with stop gap functions for `get_recent_tracks`, `get_info`
  # until Elixirfm pull requests are resolved
  # import Elixirfm.User

  @type lastfm_response :: {:ok, map} | {:error, binary, HTTPoison.Error.t}
  @default_data_dir "./lastfm_data/"

  @doc """
  Issues a request to Lastfm to extract scrobbled tracks for a user.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for details on the use of parameters.
  """
  @spec extract(binary, integer, integer, integer, integer) :: lastfm_response
  def extract(user, page \\ 1, limit \\ 1, from \\ 0, to \\ 0)

  # pending until Elixirfm dependency pull requests are resolved
  #def extract(user, page, limit, from, to), do: get_recent_tracks(user, limit: limit, page: page, extended: 1, from: from, to: to)

  # below are stop gap functions for Lastfm API requests until the Elixirfm pull requests
  # are resolved. This is to enable `lastfm_archive` publication on hex
  def extract(user, page, limit, from, to), do: get_tracks(user, limit: limit, page: page, extended: 1, from: from, to: to)

  @doc false
  def get_tracks(user, args \\ []) do
    ext_query_string = encode(args) |> Enum.join
    base_url = Application.get_env(:elixirfm, :lastfm_ws) || "http://ws.audioscrobbler.com/"
    lastfm_key = Application.get_env(:elixirfm, :api_key, System.get_env("LASTFM_API_KEY")) || raise "API key error"

    req_url = "#{base_url}2.0/?method=user.getrecenttracks&user=#{user}#{ext_query_string}&api_key=#{lastfm_key}&format=json"
    HTTPoison.get(req_url, [], [{"Authorization", "Bearer #{lastfm_key}"}])
  end
  defp encode(nil), do: ""
  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for {k, v} <- args, do: encode({k, v})

  @doc false
  def get_info(user) do
    base_url = Application.get_env(:elixirfm, :lastfm_ws) || "http://ws.audioscrobbler.com/"
    lastfm_key = Application.get_env(:elixirfm, :api_key, System.get_env("LASTFM_API_KEY")) || raise "API key error"

    req_url = "#{base_url}2.0/?method=user.getinfo&user=#{user}&api_key=#{lastfm_key}&format=json"
    {status, resp} = HTTPoison.get(req_url, [], [{"Authorization", "Bearer #{lastfm_key}"}])
    {status, resp.body |> Poison.decode!}
  end

  # --- end temporary stop gap

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
  @spec write(binary, binary | lastfm_response, binary) :: :ok | {:error, :file.posix}
  def write(user, data, filename \\ "1")

  # stop gap implementation until until Elixirfm pull requests are resolved
  def write(user, {:ok, %HTTPoison.Response{body: data, headers: _, request_url: _, status_code: _}}, filename), do: write(user, data, filename)
  def write(user, {:error, %HTTPoison.Error{id: nil, reason: reason}}, filename) do
    write(user, "error", Path.join(["error", reason|>to_string, filename]))
  end

  # pending until Elixirfm pull requests are resolved
  #def write({:ok, data}, filename), do: write(data |> Poison.encode!, filename)
  #def write({:error, _message, %HTTPoison.Error{id: nil, reason: reason}}, filename) do
    #write("error", Path.join(["error", reason|>to_string, filename]))
  #end

  def write(user, data, filename) when is_binary(data), do: _write(user, data, filename)

  defp _write(user, data, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join "#{data_dir}", "#{user}"
    unless File.exists?(user_data_dir), do: File.mkdir_p user_data_dir

    file_path = Path.join("#{user_data_dir}", "#{filename}.gz")
    file_dir = Path.dirname file_path
    unless File.exists?(file_dir), do: File.mkdir_p file_dir

    File.write file_path, data, [:compressed]
  end

  # find out more about the user (playcount, earliest scrobbles)
  # to determine data extraction strategy
  @doc false
  def info(user) do
    {_status, resp} = get_info(user)

    playcount = resp["user"]["playcount"]
    registered = resp["user"]["registered"]["unixtime"]

    {playcount, registered}
  end

  # get playcount for a particular year for a user
  @doc false
  def info(user, {from, to}) do
    # pending, with a stop gap until Elixirfm pull requests are sorted out
    # this is so that `lastfm_archive` can be published on Hex now
    #{_status, resp} = get_recent_tracks(user, limit: 1, page: 1, from: from, to: to)
    #resp["recenttracks"]["@attr"]["total"]
    
    # stop gap
    {_status, resp} = get_tracks(user, limit: 1, page: 1, from: from, to: to)
    resp_body = resp.body |> Poison.decode!
    resp_body["recenttracks"]["@attr"]["total"]
  end

end