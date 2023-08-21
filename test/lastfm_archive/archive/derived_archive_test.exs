defmodule LastfmArchive.Archive.DerivedArchiveTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
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

  setup_all do
    user = "a_lastfm_user"

    # archive with 16 months scrobbles: 2022 full year, 2023 up to Apr (4 months)
    metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2022-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()
      )
      |> Map.put(:modified, DateTime.utc_now())

    %{file_archive_metadata: metadata, user: user}
  end

  describe "after_archive/3 transform FileArchive" do
    for format <- DerivedArchive.formats() do
      test "into #{format} file", %{file_archive_metadata: metadata} do
        format = unquote(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)

        # 16 read for 16 months, each with 105 scrobbles
        FileArchiveMock
        |> expect(:read, 16, fn ^metadata, _option -> {:ok, data_frame()} end)

        FileIOMock
        |> expect(:exists?, fn _dir -> true end)
        |> expect(:exists?, 2, fn _filepath -> false end)

        if format = :csv do
          FileIOMock |> expect(:write, 2, fn _filepath, _data, [:compressed] -> :ok end)
          DataFrameMock |> expect(:"dump_#{format}!", 2, fn %DataFrame{}, _opts -> transformed_file_data(format) end)
        else
          DataFrameMock |> expect(:"to_#{format}!", 2, fn %DataFrame{}, _filepath, _opts -> :ok end)
        end

        capture_log(fn ->
          assert {:ok, _metadata} = DerivedArchive.after_archive(metadata, FileArchiveTransformer, format: format)
        end)
      end
    end
  end

  describe "describe/2" do
    for format <- DerivedArchive.formats() do
      test "existing #{format} derived archive", %{user: user, file_archive_metadata: metadata} do
        format = unquote(format)

        derived_archive_metadata = metadata |> new_derived_archive_metadata(format: format)
        derived_archive_metadata_filepath = metadata_filepath(user, format: format)
        file_archive_metadata_filepath = metadata_filepath(user, [])
        mimetype = DerivedArchive.mimetype(format)

        FileIOMock
        |> expect(:read, fn ^file_archive_metadata_filepath -> {:ok, metadata |> Jason.encode!()} end)
        |> expect(:read, fn ^derived_archive_metadata_filepath -> {:ok, derived_archive_metadata |> Jason.encode!()} end)

        assert {
                 :ok,
                 %Metadata{
                   created: %{__struct__: DateTime},
                   creator: ^user,
                   description: description,
                   format: ^mimetype,
                   identifier: ^user,
                   source: "local file archive",
                   title: "Lastfm archive of a_lastfm_user",
                   type: DerivedArchive,
                   extent: 400,
                   date: %{__struct__: Date},
                   temporal: {1_641_063_007, 1_680_547_807},
                   modified: _now
                 }
               } = DerivedArchive.describe(user, format: format)

        assert description == "Lastfm archive of a_lastfm_user in #{format} format"
      end

      test "#{format} returns new metadata when file archive exists", %{
        user: user,
        file_archive_metadata: metadata
      } do
        format = unquote(format)

        file_archive_metadata_filepath = metadata_filepath(user, [])
        derived_archive_metadata_filepath = metadata_filepath(user, format: format)
        mimetype = DerivedArchive.mimetype(format)

        FileIOMock
        |> expect(:read, fn ^file_archive_metadata_filepath -> {:ok, metadata |> Jason.encode!()} end)
        |> expect(:read, fn ^derived_archive_metadata_filepath -> {:error, :enoent} end)

        assert {
                 :ok,
                 %Metadata{
                   created: %{__struct__: DateTime},
                   creator: ^user,
                   description: description,
                   format: ^mimetype,
                   identifier: ^user,
                   source: "local file archive",
                   title: "Lastfm archive of a_lastfm_user",
                   type: DerivedArchive,
                   date: %{__struct__: Date},
                   extent: 400,
                   modified: _now,
                   temporal: {1_641_063_007, 1_680_547_807}
                 }
               } = DerivedArchive.describe(user, format: format)

        assert description == "Lastfm archive of a_lastfm_user in #{format} format"
      end
    end
  end

  describe "read/2" do
    for format <- DerivedArchive.formats() do
      test "#{format} returns data frame given a year option", %{user: user, file_archive_metadata: metadata} do
        format = unquote(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)
        opts = DerivedArchive.read_opts(format)

        filepath = Path.join([user_dir(user), "#{format}", "2023.#{format}"])
        filepath = if format == :csv, do: filepath <> ".gz", else: filepath

        DataFrameMock |> expect(:"from_#{format}!", fn ^filepath, ^opts -> data_frame() end)

        assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, year: 2023)
      end

      test "#{format} when columns options is given", %{user: user, file_archive_metadata: metadata} do
        format = unquote(format)
        columns = [:id, :album, :artist]
        metadata = metadata |> new_derived_archive_metadata(format: format)
        opts = DerivedArchive.read_opts(format) |> Keyword.put(:columns, columns)

        filepath = Path.join([user_dir(user), "#{format}", "2023.#{format}"])
        filepath = if format == :csv, do: filepath <> ".gz", else: filepath

        DataFrameMock |> expect(:"from_#{format}!", fn ^filepath, ^opts -> data_frame() end)

        assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, year: 2023, columns: columns)
      end

      test "all #{format} (years) when no year option specified", %{file_archive_metadata: metadata} do
        format = unquote(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)

        # read all (2) years from files
        DataFrameMock |> expect(:"from_#{format}!", 2, fn _filepath, _opts -> data_frame() end)
        assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, [])
      end
    end
  end
end
