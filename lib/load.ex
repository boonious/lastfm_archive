defmodule LastfmArchive.Load do
  @moduledoc """
  This module provides functions for loading Lastfm data into databases and search engines.

  """
  @default_data_dir "./lastfm_data/"

  @doc """
  Ping a Solr core/collection endpoint to check if it is running.

  The endpoint can either be a URL string or an atom referring to an endpoint in configuration.
  The library uses `Hui` to interact with Solr, an endpoint can be specified as below:

  ### Example

  ```
    LastfmArchive.Load.ping_solr("http://solr_url...")
    LastfmArchive.Load.ping_solr(:lastfm_archive) # check a configured endpoint
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
  def check_solr_schema(url) when is_atom(url) and url != nil, do: Application.get_env(:hui, url)[:url] |> check_solr_schema
  def check_solr_schema(url) when is_binary(url), do: solr_schema(url) |> check_solr_schema

  def check_solr_schema(nil), do: {:error, %Hui.Error{reason: :ehostunreach}}
  def check_solr_schema({:error, error}), do: {:error, error}

  def check_solr_schema({:ok, schema_data}) do
    schema = schema_data["schema"]
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

  @doc """
  Load a TSV file data from the archive into Solr for a Lastfm user.

  The function reads and converts scrobbles in a TSV file from the file
  archive into a list of maps. The maps are sent to Solr for ingestion.
  Use `t:Hui.URL.t/0` struct to specify the Solr endpoint.

  ### Example

  ```
    # define a Solr endpoint with %Hui.URL{} struct
    headers = [{"Content-type", "application/json"}]
    url = %Hui.URL{url: "http://localhost:8983/solr/lastfm_archive", handler: "update", headers: headers}

    # ingest data scrobbled in 2018
    LastfmArchive.Load.load_solr(url, "a_lastfm_user", "tsv/2018.tsv.gz")
  ```

  TSV files must be pre-created by transforming raw JSON Lastfm data - see
  `LastfmArchive.transform_archive/2`.

  """
  @spec load_solr(Hui.URL.t, binary, binary) :: {:ok, HTTPoison.Response.t()} | {:error, :enoent}
  def load_solr(url, user, filename) do
    {status, resp} = read(user, filename)

    case status do
      :ok ->
        [header | scrobbles] = resp
        solr_docs = for scrobble <- scrobbles, scrobble != "" do
          field_names = header |> String.split("\t")
          scrobble_data = scrobble |> String.split("\t")
          map_fields(field_names, scrobble_data, []) |> Enum.into(%{})
        end

        Hui.update(url, solr_docs)
      :error ->
        {:error, resp}
    end
  end

  defp map_fields(_, [], acc), do: acc
  defp map_fields([field_name|field_names], [data | rest_of_data], acc) do
    map_fields(field_names, rest_of_data, acc ++ [{field_name, data}])
  end

  @doc """
  Read and parse a TSV file from the archive for a Lastfm user.

  TSV files generated by transforming raw JSON Lastfm data - see
  `LastfmArchive.transform_archive/2`. The file is parsed
  into a list of scrobbles.

  ### Example

  ```
    LastfmArchive.Load.read "a_lastfm_user", "tsv/2007.tsv.gz"
  ```
  """

  # need to consolidate this with read functions from other modules,
  # e.g. into a generic read function under a separate IO module
  @spec read(binary, binary) :: {:ok, list(binary)} | {:error, :file.posix}
  def read(user, filename) do
    data_dir = Application.get_env(:lastfm_archive, :data_dir) || @default_data_dir
    user_data_dir = Path.join data_dir, user
    file_path = Path.join user_data_dir, filename

    {status, file_io} = File.open(file_path, [:read, :compressed, :utf8])
    resp = case status do
      :ok ->
        {:ok, IO.read(file_io, :all) |> String.split("\n")}
      :error ->
        {:error, file_io}
    end

    if is_pid(file_io), do: File.close(file_io)
    resp
  end

end