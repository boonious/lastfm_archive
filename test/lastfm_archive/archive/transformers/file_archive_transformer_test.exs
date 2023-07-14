defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Fixtures.Archive
  import Hammox
  import LastfmArchive.Utils, only: [user_dir: 1]

  alias LastfmArchive.Archive.DerivedArchive
  alias LastfmArchive.Archive.FileArchiveMock
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
        start: DateTime.from_iso8601("2022-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: FileArchive,
        date: ~D[2023-04-03]
      )

    %{user: user, metadata: metadata}
  end

  describe "apply/3" do
    test "csv transformation", %{user: user, metadata: metadata} do
      format = :csv
      opts = DerivedArchive.write_opts(format)
      dir = Path.join(user_dir(user), "#{format}")

      filepath1 = Path.join([user_dir(user), "#{format}", "2022.#{format}.gz"])
      filepath2 = Path.join([user_dir(user), "#{format}", "2023.#{format}.gz"])

      # read archive 16 times per 16 months scrobbles, 105 scrobbles each month
      FileArchiveMock
      |> expect(:read, 16, fn ^metadata, _option -> {:ok, data_frame()} end)

      FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:exists?, fn ^filepath1 -> false end)
      |> expect(:exists?, fn ^filepath2 -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^filepath1, _data, [:compressed] -> :ok end)
      |> expect(:write, fn ^filepath2, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^opts ->
        # whole year of scrobbles
        assert df |> DataFrame.shape() == {12 * 105, 11}
        transformed_file_data(format)
      end)
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^opts ->
        # 4 month of scrobbles
        assert df |> DataFrame.shape() == {4 * 105, 11}
        transformed_file_data(format)
      end)

      assert capture_log(fn -> assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: format) end) =~
               "Creating"
    end

    for format <- DerivedArchive.formats() do
      if format != :csv do
        test "#{format} transformation", %{user: user, metadata: metadata} do
          format = unquote(format)
          opts = DerivedArchive.write_opts(format)
          dir = Path.join(user_dir(user), "#{format}")

          filepath1 = Path.join([user_dir(user), "#{format}", "2022.#{format}"])
          filepath2 = Path.join([user_dir(user), "#{format}", "2023.#{format}"])

          # read archive 16 times per 16 months scrobbles, 105 scrobbles each month
          FileArchiveMock
          |> expect(:read, 16, fn ^metadata, _option -> {:ok, data_frame()} end)

          FileIOMock
          |> expect(:exists?, fn ^dir -> false end)
          |> expect(:exists?, fn ^filepath1 -> false end)
          |> expect(:exists?, fn ^filepath2 -> false end)
          |> expect(:mkdir_p, fn ^dir -> :ok end)

          DataFrameMock
          |> expect(:"to_#{format}!", fn %DataFrame{} = df, ^filepath1, ^opts ->
            # whole year of scrobbles
            assert df |> DataFrame.shape() == {12 * 105, 11}
            :ok
          end)
          |> expect(:"to_#{format}!", fn %DataFrame{} = df, ^filepath2, ^opts ->
            # 4 month of scrobbles
            assert df |> DataFrame.shape() == {4 * 105, 11}
            :ok
          end)

          assert capture_log(fn -> assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: format) end) =~
                   "Creating"
        end
      end

      test "does not overwrite existing #{format} file", %{user: user, metadata: metadata} do
        format = unquote(format)
        opts = DerivedArchive.write_opts(format)
        dir = Path.join(user_dir(user), "#{format}")

        FileIOMock
        |> expect(:exists?, fn ^dir -> true end)
        |> stub(:exists?, fn _filepath -> true end)
        |> expect(:write, 0, fn __filepath, _data, [:compressed] -> :ok end)

        DataFrameMock
        |> expect(:"dump_#{format}!", 0, fn _df, ^opts -> transformed_file_data(format) end)
        |> expect(:"to_#{format}!", 0, fn _df, _filepath, ^opts -> :ok end)

        assert capture_log(fn -> assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: format) end) =~
                 "skipping"
      end

      test "overwrites existing #{format} file when opted", %{metadata: metadata} do
        format = unquote(format)
        opts = DerivedArchive.write_opts(format)

        FileArchiveMock
        |> stub(:read, fn ^metadata, _option -> {:ok, data_frame()} end)

        FileIOMock
        |> expect(:exists?, fn _dir -> true end)
        |> stub(:exists?, fn _filepath -> true end)
        |> stub(:write, fn __filepath, _data, [:compressed] -> :ok end)

        DataFrameMock
        |> stub(:"dump_#{format}!", fn %DataFrame{}, ^opts -> transformed_file_data(format) end)
        |> stub(:"to_#{format}!", fn %DataFrame{}, _filepath, ^opts -> :ok end)

        assert capture_log(fn ->
                 assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: format, overwrite: true)
               end) =~
                 "Creating"
      end
    end
  end
end
