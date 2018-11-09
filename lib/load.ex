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

  @doc """
  Check a Solr core/collection to ensure it has the required Lastfm data fields.

  The check currently inspects Solr schema for a list of Lastfm fields
  and returns error if one or more of the fields are missing.
  See `LastfmArchive.Transform.transform/3` for the list of fields.

  ### Example

  ```
    LastfmArchive.Load.check_solr_schema("http://solr_url...")
    LastfmArchive.Load.check_solr_schema(:lastfm_archive) # ping a configured endpoint
  ```

  See `ping_solr/1` for more details on URL configuration.
  """
  @spec check_solr_schema(binary|atom) :: {:ok, map} | {:error, Hui.Error.t}
  def check_solr_schema(url) when is_atom(url), do: Application.get_env(:hui, url)[:url] |> check_solr_schema
  def check_solr_schema(url) when is_binary(url) do
    {:ok, schema_resp} = solr_schema(url)
    schema = schema_resp["schema"]
    fields = schema["fields"] |> Enum.map(&(&1["name"]))

    {:ok, fields_s} = File.read("./solr/fields.json")
    expected_fields = fields_s |> Poison.decode!

    # simple check if field exists, no type checking for the time being
    missing_fields = for {field, _type} <- expected_fields, do: unless Enum.member?(fields, field), do: field
    missing_fields = missing_fields |> Enum.uniq |> List.delete(nil)

    if length(missing_fields) > 0 do 
      {:error, %Hui.Error{reason: :einit}}
    else 
      {:ok, expected_fields}
    end
  end

  defp solr_schema(url) do
    response = HTTPoison.get url <> "/schema"
    
    case response do
      {:ok, resp} -> 
        if resp.status_code == 200, do: {:ok, resp.body |> Poison.decode!}, else: {:error, %Hui.Error{reason: :ehostunreach}}
      {:error, %HTTPoison.Error{id: _, reason: reason}} ->
        {:error, %Hui.Error{reason: reason}}
    end
  end

end
