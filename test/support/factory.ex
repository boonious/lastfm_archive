defmodule LastfmArchive.Factory do
  @moduledoc false
  use ExMachina
  use LastfmArchive.Lastfm.Factory

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Scrobble

  alias Explorer.DataFrame

  # 200 test music track samples
  @samples_path "test/fixtures/lastfm_scrobble_samples.ipc_stream"
  @samples DataFrame.from_ipc_stream!(@samples_path)
           |> DataFrame.to_rows()
           |> Jason.encode!()
           |> Jason.decode!(keys: :atoms)

  def file_archive_metadata_factory(attrs) do
    first_scrobble_time = Map.get(attrs, :first_scrobble_time, first_scrobble_time(attrs))
    latest_scrobble_time = Map.get(attrs, :latest_scrobble_time, latest_scrobble_time(attrs))
    user = Map.get(attrs, :creator, "a_lastfm_user")

    %Metadata{
      created: DateTime.utc_now(),
      creator: user,
      date: Map.get(attrs, :date, ~D[2021-04-03]),
      description: "Lastfm archive of #{user}, extracted from Lastfm API",
      extent: Map.get(attrs, :total, 388),
      format: "application/json",
      identifier: user,
      modified: Map.get(attrs, :modified, DateTime.from_iso8601("2023-06-09T14:36:16.952540Z") |> elem(1)),
      source: "http://ws.audioscrobbler.com/2.0",
      temporal: {first_scrobble_time, latest_scrobble_time},
      title: "Lastfm archive of #{user}",
      type: Map.get(attrs, :type, :scrobbles)
    }
  end

  def derived_archive_metadata_factory(attrs) do
    opts = Map.get(attrs, :options, [])

    Map.get(attrs, :file_archive_metadata, build(:file_archive_metadata, attrs))
    |> Metadata.new(opts)
  end

  defp first_scrobble_time(attrs) do
    Map.get(
      attrs,
      :first_scrobble_time,
      DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    )
  end

  defp latest_scrobble_time(attrs) do
    Map.get(
      attrs,
      :latest_scrobble_time,
      DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    )
  end

  def scrobble_factory(attrs) do
    date = Map.get(attrs, :date, Date.utc_today())
    date_time = Map.get(attrs, :date_time, DateTime.new!(date, ~T[06:00:08.003], "Etc/UTC"))

    unix_time = (date_time |> DateTime.to_unix()) + next_time()
    date_time = DateTime.from_unix!(unix_time)
    sample = sample()

    %Scrobble{
      id: UUID.uuid4(),
      album_mbid: Map.get(attrs, :album_mbid, sample[:album_mbid]),
      album: Map.get(attrs, :album, sample[:album]),
      artist_url: Map.get(attrs, :artist_url, sample[:artist_url]),
      artist_mbid: Map.get(attrs, :artist_mbid, sample[:artist_mbid]),
      artist: Map.get(attrs, :artist, sample[:artist]),
      year: date_time.year,
      mmdd: date_time |> Calendar.strftime("%m%d"),
      date: date_time |> DateTime.to_date(),
      datetime: date_time |> DateTime.to_naive(),
      datetime_unix: unix_time,
      url: Map.get(attrs, :url, sample[:url]),
      name: Map.get(attrs, :track) || Map.get(attrs, :name) || sample[:track],
      mbid: Map.get(attrs, :mbid, sample[:mbid])
    }
  end

  # add 2-4 minutes for next trak play time
  defp next_time(), do: sequence("") |> String.to_integer() |> Kernel.*(Enum.random(120..420))

  def scrobbles_factory(attrs) do
    ExMachina.Sequence.reset("")
    Map.get(attrs, :num_of_plays, 10) |> build_list(:scrobble, attrs) |> Enum.sort_by(& &1.datetime)
  end

  def dataframe(scrobbles \\ build(:scrobbles)) do
    scrobbles
    |> Enum.map(&Map.from_struct/1)
    |> DataFrame.new(lazy: true)
    |> DataFrame.rename(name: "track")
  end

  def scrobbles_csv_gzipped() do
    [build(:scrobble)] |> dataframe() |> DataFrame.collect() |> DataFrame.dump_csv!(delimiter: "\t") |> :zlib.gzip()
  end

  defp sample, do: @samples |> Enum.random()

  def solr_add_docs(), do: File.read!("test/fixtures/solr_add_docs.json")
  def solr_schema_response(), do: File.read!("test/fixtures/solr_schema_response.json")
  def solr_missing_fields_response(), do: File.read!("test/fixtures/solr_missing_fields_response.json")
end
