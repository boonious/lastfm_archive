defmodule Lastfm.Extract do
  @moduledoc """
  This module implements Lastfm.Client behaviour to extract data from Lastfm API.
  """

  @behaviour Lastfm.Client

  alias Lastfm.Client

  @impl true
  def info(user, api \\ %Client{method: "user.getinfo"}) do
    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json"
    |> get(api.api_key)
    |> case do
      %{"user" => _} = resp ->
        {
          resp["user"]["playcount"],
          resp["user"]["registered"]["unixtime"]
        }
        |> format_count()

      %{"error" => _, "message" => message} ->
        raise message
    end
  end

  @impl true
  def scrobbles(user, {page, limit, from, to}, api \\ %Client{method: "user.getrecenttracks"}) do
    extra_query = [limit: limit, page: page, from: from, to: to, extended: 1] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json#{extra_query}"
    |> get(api.api_key)
    |> case do
      %{"recenttracks" => _} = scrobbles ->
        scrobbles

      %{"error" => _, "message" => message} ->
        raise message
    end
  end

  @impl true
  def playcount(user, {from, to}, api \\ %Client{method: "user.getrecenttracks"}) do
    extra_query = [limit: 1, page: 1, from: from, to: to] |> encode() |> Enum.join()

    "#{api.endpoint}2.0/?method=#{api.method}&user=#{user}&api_key=#{api.api_key}&format=json#{extra_query}"
    |> get(api.api_key)
    |> case do
      %{"recenttracks" => _} = resp ->
        resp["recenttracks"]["@attr"]["total"] |> format_count()

      %{"error" => _, "message" => message} ->
        raise message
    end
  end

  defp get(url, key) do
    :httpc.request(:get, {to_charlist(url), [{'Authorization', to_charlist("Bearer #{key}")}]}, [], [])
    |> case do
      {:ok, {{_scheme, _status, _}, _headers, body}} ->
        body |> Jason.decode!()

      _ ->
        raise "failed to connect with Lastfm API"
    end
  end

  defp encode(nil), do: ""
  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for({k, v} <- args, do: encode({k, v}))

  defp format_count(count) when is_integer(count), do: count
  defp format_count(count) when is_binary(count), do: count |> String.to_integer()

  defp format_count({count, registered}) when is_integer(count) and is_integer(registered),
    do: {count, registered}

  defp format_count({count, registered}) when is_binary(count) or is_binary(registered) do
    {count |> String.to_integer(), registered |> String.to_integer()}
  end

  defp format_count({nil, nil}), do: {0, 0}
  defp format_count(nil), do: 0
end
