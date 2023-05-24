defmodule LastfmArchive.LastfmClient do
  @moduledoc """
  Client for extracting Lastfm user info and scrobbles data via the official API.
  """

  @behaviour LastfmArchive.Behaviour.LastfmClient

  @api Application.compile_env(:lastfm_archive, :api)
  @config_user Application.compile_env(:lastfm_archive, :user)

  defstruct [:api_key, :endpoint, :method]

  @type t :: %__MODULE__{
          api_key: binary,
          endpoint: binary,
          method: binary
        }

  def default_user, do: System.get_env("LB_LFM_USER") || @config_user

  def new(method) do
    %__MODULE__{
      api_key: System.get_env("LB_LFM_API_KEY") || @api[:api_key] || "",
      endpoint: System.get_env("LB_LFM_API_ENDPOINT") || @api[:endpoint] || "",
      method: method
    }
  end

  @doc """
  Returns the total playcount and earliest scrobble date for a user.
  """
  @impl true
  def info(user \\ default_user(), client \\ new("user.getinfo")) do
    "#{client.endpoint}2.0/?method=#{client.method}&user=#{user}&api_key=#{client.api_key}&format=json"
    |> get(client.api_key)
    |> handle_response(:info)
  end

  @doc """
  Returns the scrobbles of a user for a given time range.

  See Lastfm API [documentation](https://www.last.fm/api/show/user.getRecentTracks) for more details.
  """
  @impl true
  def scrobbles(user \\ default_user(), page_params \\ {1, 1, nil, nil}, client \\ new("user.getrecenttracks"))

  def scrobbles(user, {page, limit, from, to}, client) do
    extra_query = [limit: limit, page: page, from: from, to: to, extended: 1] |> encode() |> Enum.join()

    "#{client.endpoint}2.0/?method=#{client.method}&user=#{user}&api_key=#{client.api_key}&format=json#{extra_query}"
    |> get(client.api_key)
    |> handle_response(:scrobbles)
  end

  @doc """
  Returns the playcount of a user for a given time range.
  """
  @impl true
  def playcount(user \\ default_user(), {from, to} \\ {nil, nil}, client \\ new("user.getrecenttracks")) do
    extra_query = [limit: 1, page: 1, from: from, to: to] |> encode() |> Enum.join()

    "#{client.endpoint}2.0/?method=#{client.method}&user=#{user}&api_key=#{client.api_key}&format=json#{extra_query}"
    |> get(client.api_key)
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

  defp encode(nil), do: ""
  defp encode({_k, 0}), do: ""
  defp encode({k, v}), do: "&#{k}=#{v}"
  defp encode(args), do: for({k, v} <- args, v != nil, do: encode({k, v}))
end
