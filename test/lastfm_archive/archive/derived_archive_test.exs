defmodule LastfmArchive.Archive.DerivedArchiveTest do
  use ExUnit.Case, async: true

  import Fixtures.Archive
  import Hammox
  import LastfmArchive.Utils, only: [user_dir: 1, metadata_filepath: 2]

  alias LastfmArchive.Archive.DerivedArchive
  alias LastfmArchive.Archive.FileArchiveMock
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Transformers.FileArchiveTransformer
  alias LastfmArchive.FileIOMock

  alias Explorer.DataFrame
  alias Explorer.DataFrameMock

  setup :verify_on_exit!

  setup do
    user = "a_lastfm_user"

    file_archive_metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2023-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: DerivedArchive
      )
      |> Map.put(:modified, DateTime.utc_now())

    derived_archive_metadata = file_archive_metadata |> new_derived_archive_metadata(format: :csv)

    %{
      dir: Path.join(user_dir(user), "csv"),
      derived_archive_metadata: derived_archive_metadata,
      file_archive_metadata: file_archive_metadata,
      user: user
    }
  end

  describe "after_archive/3" do
    test "transform FileArchive into CSV file", %{dir: dir, derived_archive_metadata: metadata, user: user} do
      filepath = Path.join([user_dir(user), "csv", "2023.csv.gz"])

      # 4 read for 4 months, each with 105 scrobbles
      FileArchiveMock
      |> expect(:read, 4, fn ^metadata, _option -> {:ok, data_frame()} end)

      FileIOMock
      |> expect(:exists?, fn ^dir -> true end)
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:dump_csv!, fn %DataFrame{} = df, [delimiter: "\t"] ->
        # 4 month of scrobbles
        assert df |> DataFrame.shape() == {4 * 105, 11}
        csv_data()
      end)

      assert {:ok, _metadata} = DerivedArchive.after_archive(metadata, FileArchiveTransformer, format: :csv)
    end
  end

  describe "describe/2" do
    test "an existing derived archive", %{user: user, derived_archive_metadata: metadata} do
      metadata_filepath = metadata_filepath(user, format: :csv)
      LastfmArchive.FileIOMock |> expect(:read, fn ^metadata_filepath -> {:ok, metadata |> Jason.encode!()} end)

      assert {
               :ok,
               %Metadata{
                 created: %{__struct__: DateTime},
                 creator: ^user,
                 description: "Lastfm archive of a_lastfm_user in csv format",
                 format: "text/tab-separated-values",
                 identifier: ^user,
                 source: "local file archive",
                 title: "Lastfm archive of a_lastfm_user",
                 type: DerivedArchive,
                 extent: 400,
                 date: %{__struct__: Date},
                 temporal: {1_672_599_007, 1_680_547_807},
                 modified: _now
               }
             } = DerivedArchive.describe(user, format: :csv)
    end

    test "returns new metadata when file archive exists", %{
      user: user,
      derived_archive_metadata: _metadata,
      file_archive_metadata: file_archive_metadata
    } do
      file_archive_metadata_filepath = metadata_filepath(user, [])
      derived_archive_metadata_filepath = metadata_filepath(user, format: :csv)

      LastfmArchive.FileIOMock
      |> expect(:read, fn ^derived_archive_metadata_filepath -> {:error, :enoent} end)
      |> expect(:read, fn ^file_archive_metadata_filepath -> {:ok, file_archive_metadata |> Jason.encode!()} end)

      assert {
               :ok,
               %Metadata{
                 created: %{__struct__: DateTime},
                 creator: ^user,
                 description: "Lastfm archive of a_lastfm_user in csv format",
                 format: "text/tab-separated-values",
                 identifier: ^user,
                 source: "local file archive",
                 title: "Lastfm archive of a_lastfm_user",
                 type: DerivedArchive,
                 date: %{__struct__: Date},
                 extent: 400,
                 modified: _now,
                 temporal: {1_672_599_007, 1_680_547_807}
               }
             } = DerivedArchive.describe(user, format: :csv)
    end
  end

  describe "read/2" do
    test "returns data frame based on a year CSV file", %{user: user, derived_archive_metadata: metadata} do
      filepath = Path.join([user_dir(user), "csv", "2023.csv.gz"])

      FileIOMock |> expect(:read, fn ^filepath -> {:ok, File.read!("test/fixtures/2023.csv.gz")} end)
      DataFrameMock |> expect(:load_csv!, fn _data, [delimiter: "\t"] -> data_frame() end)

      assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, year: 2023)
    end

    test "returns data frame based on a year Parquet file", %{user: user, derived_archive_metadata: metadata} do
      filepath = Path.join([user_dir(user), "parquet", "2023.parquet.gz"])
      metadata = %{metadata | format: "application/vnd.apache.parquet"}

      FileIOMock |> expect(:read, fn ^filepath -> {:ok, File.read!("test/fixtures/2023.parquet.gz")} end)
      DataFrameMock |> expect(:load_parquet!, fn _data, [] -> data_frame() end)

      assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, year: 2023)
    end

    test "when year option given", %{derived_archive_metadata: metadata} do
      assert {:error, _reason} = DerivedArchive.read(metadata, [])
    end
  end
end
