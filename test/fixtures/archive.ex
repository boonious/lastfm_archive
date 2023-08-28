defmodule Fixtures.Archive do
  @moduledoc false
  alias LastfmArchive.Archive.FileArchive
  alias LastfmArchive.Archive.Metadata

  @default_user Application.compile_env(:lastfm_archive, :user)
  @registered_time DateTime.from_iso8601("2021-04-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
  @latest_scrobble_time DateTime.from_iso8601("2021-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
  @date ~D[2021-04-03]
  @total 400

  def file_archive_metadata(), do: test_archive(@default_user)
  def file_archive_metadata(@default_user), do: test_archive(@default_user)

  def file_archive_metadata(user), do: test_archive(user)
  def file_archive_metadata(user, created_datetime), do: %{test_archive(user) | created: created_datetime}

  @spec new_archive_metadata(keyword) :: LastfmArchive.Archive.Metadata.t()
  def new_archive_metadata(args) when is_list(args) do
    args =
      Keyword.validate!(args,
        user: "a_lastfm_user",
        start: @registered_time,
        end: @latest_scrobble_time,
        date: @date,
        type: :scrobbles,
        total: @total
      )

    %{
      Metadata.new(Keyword.get(args, :user))
      | temporal: {Keyword.get(args, :start), Keyword.get(args, :end)},
        extent: Keyword.get(args, :total),
        date: Keyword.get(args, :date),
        type: Keyword.get(args, :type)
    }
  end

  def new_derived_archive_metadata(file_archive_metadata, options) do
    Metadata.new(file_archive_metadata, options)
  end

  defp test_archive(user) do
    %{
      Metadata.new(user)
      | temporal: {@registered_time, @latest_scrobble_time},
        extent: 400,
        date: ~D[2021-04-03],
        modified: "2023-06-09T14:36:16.952540Z"
    }
  end

  def data_frame(data \\ scrobbles_json()) do
    data
    |> Jason.decode!()
    |> LastfmArchive.Archive.Scrobble.new()
    |> Enum.map(&Map.from_struct/1)
    |> Explorer.DataFrame.new(lazy: true)
  end

  def transformed_file_data(format \\ :csv), do: File.read!("test/fixtures/2023.#{format}")

  def archive_metadata(), do: File.read!("test/fixtures/metadata.json")

  def scrobbles_json(), do: gzipped_scrobbles() |> :zlib.gunzip()
  def gzipped_scrobbles(), do: File.read!("test/fixtures/200_001.gz")
  def gzip_data(), do: File.read!("test/fixtures/200_34.gz")
  def csv_gzip_data(), do: File.read!("test/fixtures/2018.csv.gz")

  def solr_add_docs(), do: File.read!("test/fixtures/solr_add_docs.json")
  def solr_schema_response(), do: File.read!("test/fixtures/solr_schema_response.json")
  def solr_missing_fields_response(), do: File.read!("test/fixtures/solr_missing_fields_response.json")
end
