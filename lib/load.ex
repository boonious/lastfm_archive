defmodule LastfmArchive.Load do
  @moduledoc """
  This module provides functions for loading Lastfm data into databases and search engines.

  """

  @doc """
  Ping a Solr core/collection endpoint to check if it is running.

  The endpoint can either be a URL string or an atom referring to an endpoint in configuration.
  The library uses `Hui` to interact with Solr, an endpoint can be specified as below:
  
  ### Example
  
  ```
    LastfmArchive.Load.ping_solr("http://solr_url...")
    LastfmArchive.Load.ping_solr(:lastfm_archive) # ping a configured endpoint 
  ```

  `:lastfm_archive` refers to the following Solr update endpoint in configuration:
  
  ```
    config :hui, :lastfm_archive,
      url: "http://solr_url..",
      handler: "update",
      headers: [{"Content-type", "application/json"}]
  ```

  See `Hui.URL` module for more details.
  """
  @spec ping_solr(binary|atom) :: {:ok, map} | {:error, Hui.Error.t}
  def ping_solr(url) when is_atom(url), do: Application.get_env(:hui, url)[:url] |> ping_solr
  def ping_solr(url) when is_binary(url) do
    response = HTTPoison.get url <> "/admin/ping"
 
    case response do
      {:ok, resp} -> 
        if resp.status_code == 200, do: {:ok, resp.body |> Poison.decode!}, else: {:error, %Hui.Error{reason: :einval}}
      {:error, %HTTPoison.Error{id: _, reason: reason}} -> 
        {:error, %Hui.Error{reason: reason}}
    end
  end
  
end
