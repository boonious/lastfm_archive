defmodule Lastfm.Extract do
  @moduledoc """
  This module implements Lastfm.Client behaviour for extracting data from Lastfm API.
  """

  @behaviour Lastfm.Client

  @doc """
  Returns the total playcount and earliest scrobble date for a user.
  """
  @impl true
  def info(user, api \\ %Lastfm.Client{method: "user.getinfo"}) do
    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json"
    |> get(api.api_key)
    |> handle_response(:info)
  end

  @doc """
  Returns the scrobbles of a user for a given time range.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for more details.
  """
  @impl true
  def scrobbles(user, page_params \\ {1, 1, nil, nil}, api \\ %Lastfm.Client{method: "user.getrecenttracks"})

  def scrobbles(user, {page, limit, from, to}, api) do
    extra_query = [limit: limit, page: page, from: from, to: to, extended: 1] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json#{extra_query}"
    |> get(api.api_key)
    |> handle_response(:scrobbles)
  end

  @doc """
  Returns the playcount of a user for a given time range.
  """
  @impl true
  def playcount(user, {from, to} \\ {nil, nil}, api \\ %Lastfm.Client{method: "user.getrecenttracks"}) do
    extra_query = [limit: 1, page: 1, from: from, to: to] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json#{extra_query}"
    |> get(api.api_key)
    |> handle_response(:playcount)
  end

  defp handle_response(%{"user" => _} = resp, _type) do
    {
      resp["user"]["playcount"] |> format(),
      resp["user"]["registered"]["unixtime"] |> format()
    }
  end

  defp handle_response(%{"recenttracks" => _} = resp, :playcount) do
    {
      resp["recenttracks"]["@attr"]["total"] |> format(),
      resp["recenttracks"]["track"] |> Enum.find(& &1["date"]) |> get_in(["date", "uts"]) |> format()
    }
  end

  defp handle_response(%{"recenttracks" => _} = resp, _type), do: resp
  defp handle_response(%{"error" => _, "message" => message}, _type), do: {:error, message}
  defp handle_response({:error, reason}, _type), do: {:error, reason}

  defp format(number) when is_integer(number), do: number
  defp format(number) when is_binary(number), do: number |> String.to_integer()
  defp format(nil), do: 0

  defp get(url, key) do
    :httpc.request(:get, {to_charlist(url), [{'Authorization', to_charlist("Bearer #{key}")}]}, [], [])
    |> case do
      {:ok, {{_scheme, _status, _}, _headers, body}} -> body |> Jason.decode!()
      {:error, error} -> {:error, error}
    end
  end

  defp encode(nil), do: ""
  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for({k, v} <- args, v != nil, do: encode({k, v}))
end
