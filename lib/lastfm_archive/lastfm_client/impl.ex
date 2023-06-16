defmodule LastfmArchive.LastfmClient.Impl do
  @moduledoc """
  Client for extracting Lastfm user info and scrobbles data via the official API.
  """

  @behaviour LastfmArchive.Behaviour.LastfmClient

  alias LastfmArchive.LastfmClient.LastfmApi

  @config_user Application.compile_env(:lastfm_archive, :user)

  def default_user, do: System.get_env("LB_LFM_USER") || @config_user

  @doc """
  Returns the total playcount and earliest scrobble date for a user.
  """
  @impl true
  def info(user \\ default_user(), api \\ LastfmApi.new("user.getinfo")) do
    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.key}&format=json"
    |> get(api.key)
    |> handle_response(:info)
  end

  @doc """
  Returns the scrobbles of a user for a given time range.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for more details.
  """
  @impl true
  def scrobbles(user, {page, limit, from, to}, api) do
    # can incorporate these into the Api struct
    extra_query = [limit: limit, page: page, from: from, to: to, extended: 1] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.key}&format=json#{extra_query}"
    |> get(api.key)
    |> handle_response(:scrobbles)
  end

  @doc """
  Returns the playcount of a user for a given time range.
  """
  @impl true
  def playcount(user \\ default_user(), {from, to} \\ {nil, nil}, api \\ LastfmApi.new()) do
    extra_query = [limit: 1, page: 1, from: from, to: to] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.key}&format=json#{extra_query}"
    |> get(api.key)
    |> handle_response(:playcount)
  end

  defp handle_response(%{"user" => _} = resp, _type) do
    {
      :ok,
      {
        resp["user"]["playcount"] |> format(),
        resp["user"]["registered"]["unixtime"] |> format()
      }
    }
  end

  defp handle_response(%{"recenttracks" => _} = resp, :playcount) do
    {
      :ok,
      {
        resp["recenttracks"]["@attr"]["total"] |> format(),
        resp["recenttracks"]["track"]
        |> List.wrap()
        |> Enum.find(& &1["date"])
        |> get_in(["date", "uts"])
        |> format()
      }
    }
  end

  defp handle_response(%{"recenttracks" => _} = resp, _type), do: {:ok, resp}
  defp handle_response(%{"error" => _, "message" => message}, _type), do: {:error, message}
  defp handle_response({:error, reason}, _type), do: {:error, reason}

  defp format(number) when is_integer(number), do: number
  defp format(number) when is_binary(number), do: number |> String.to_integer()
  defp format(nil), do: nil

  defp get(url, key) do
    :httpc.request(:get, {to_charlist(url), [{'Authorization', to_charlist("Bearer #{key}")}]}, [], [])
    |> case do
      {:ok, {{_scheme, _status, _}, _headers, body}} -> body |> Jason.decode!()
      {:error, error} -> {:error, error}
    end
  end

  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for({k, v} <- args, v != nil, do: encode({k, v}))
end
