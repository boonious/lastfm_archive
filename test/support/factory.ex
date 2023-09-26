defmodule LastfmArchive.Factory do
  @moduledoc false
  use ExMachina

  use LastfmArchive.Archive.Factory
  use LastfmArchive.DataFrame.Factory
  use LastfmArchive.Lastfm.Factory

  alias Explorer.DataFrame

  # 200 test music track samples
  @samples_path "test/fixtures/lastfm_scrobble_samples.ipc_stream"
  @samples DataFrame.from_ipc_stream!(@samples_path)
           |> DataFrame.to_rows()
           |> Jason.encode!()
           |> Jason.decode!(keys: :atoms)

  def scrobbles_csv_gzipped() do
    [build(:scrobble)] |> dataframe() |> DataFrame.collect() |> DataFrame.dump_csv!(delimiter: "\t") |> :zlib.gzip()
  end

  defp sample, do: @samples |> Enum.random()

  def solr_add_docs(), do: File.read!("test/fixtures/solr_add_docs.json")
  def solr_schema_response(), do: File.read!("test/fixtures/solr_schema_response.json")
  def solr_missing_fields_response(), do: File.read!("test/fixtures/solr_missing_fields_response.json")
end
