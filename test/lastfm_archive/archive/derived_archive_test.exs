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

    metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2023-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: DerivedArchive
      )
      |> Map.put(:modified, DateTime.utc_now())

    %{file_archive_metadata: metadata, user: user}
  end

  describe "after_archive/3 transform FileArchive" do
    test "into csv file", %{file_archive_metadata: metadata, user: user} do
      format = :csv
      dir = Path.join(user_dir(user), "#{format}")
      opts = DerivedArchive.write_opts(format)
      metadata = metadata |> new_derived_archive_metadata(format: format)

      filepath = Path.join([user_dir(user), "#{format}", "2023.#{format}.gz"])

      # 4 read for 4 months, each with 105 scrobbles
      FileArchiveMock
      |> expect(:read, 4, fn ^metadata, _option -> {:ok, data_frame()} end)

      FileIOMock
      |> expect(:exists?, fn ^dir -> true end)
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^opts ->
        # 4 month of scrobbles
        assert df |> DataFrame.shape() == {4 * 105, 11}
        transformed_file_data(format)
      end)

      assert {:ok, _metadata} = DerivedArchive.after_archive(metadata, FileArchiveTransformer, format: format)
    end

    for format <- DerivedArchive.formats(), format != :csv do
      test "into #{format} file", %{file_archive_metadata: metadata, user: user} do
        format = unquote(format)
        dir = Path.join(user_dir(user), "#{format}")
        opts = DerivedArchive.write_opts(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)
        filepath = Path.join([user_dir(user), "#{format}", "2023.#{format}"])

        # 4 read for 4 months, each with 105 scrobbles
        FileArchiveMock
        |> expect(:read, 4, fn ^metadata, _option -> {:ok, data_frame()} end)

        FileIOMock
        |> expect(:exists?, fn ^dir -> true end)
        |> expect(:exists?, fn ^filepath -> false end)

        DataFrameMock
        |> expect(:"to_#{format}!", fn %DataFrame{} = df, ^filepath, ^opts ->
          # 4 month of scrobbles
          assert df |> DataFrame.shape() == {4 * 105, 11}
          :ok
        end)

        assert {:ok, _metadata} = DerivedArchive.after_archive(metadata, FileArchiveTransformer, format: format)
      end
    end
  end

  describe "describe/2" do
    for format <- DerivedArchive.formats() do
      test "existing #{format} derived archive", %{user: user, file_archive_metadata: metadata} do
        format = unquote(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)
        metadata_filepath = metadata_filepath(user, format: format)
        mimetype = DerivedArchive.mimetype(format)

        LastfmArchive.FileIOMock |> expect(:read, fn ^metadata_filepath -> {:ok, metadata |> Jason.encode!()} end)

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
                   temporal: {1_672_599_007, 1_680_547_807},
                   modified: _now
                 }
               } = DerivedArchive.describe(user, format: format)

        assert description == "Lastfm archive of a_lastfm_user in #{format} format"
      end

      test "#{format} returns new metadata when file archive exists", %{
        user: user,
        file_archive_metadata: file_archive_metadata
      } do
        format = unquote(format)
        file_archive_metadata_filepath = metadata_filepath(user, [])
        derived_archive_metadata_filepath = metadata_filepath(user, format: format)
        mimetype = DerivedArchive.mimetype(format)

        LastfmArchive.FileIOMock
        |> expect(:read, fn ^derived_archive_metadata_filepath -> {:error, :enoent} end)
        |> expect(:read, fn ^file_archive_metadata_filepath -> {:ok, file_archive_metadata |> Jason.encode!()} end)

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
                   temporal: {1_672_599_007, 1_680_547_807}
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

      test "#{format} when no year option given", %{file_archive_metadata: metadata} do
        format = unquote(format)
        metadata = metadata |> new_derived_archive_metadata(format: format)
        assert :error = DerivedArchive.read(metadata, [])
      end
    end
  end
end
