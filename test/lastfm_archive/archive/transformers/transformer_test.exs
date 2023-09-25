defmodule LastfmArchive.Archive.Transformers.TransformerTest do
  use ExUnit.Case

  alias Explorer.DataFrame
  alias Explorer.DataFrameMock

  alias LastfmArchive.Archive.FileArchiveMock
  alias LastfmArchive.Archive.Transformers.Transformer
  alias LastfmArchive.FileIOMock

  import ExUnit.CaptureLog
  import Hammox

  import LastfmArchive.Archive.Transformers.TransformerSettings, only: [validate_opts: 1]
  import LastfmArchive.Factory, only: [build: 2, scrobbles_csv_gzipped: 0, dataframe: 0]
  import LastfmArchive.Utils.Archive, only: [derived_archive_dir: 1, user_dir: 1]

  require Explorer.DataFrame

  @column_count (%LastfmArchive.Archive.Scrobble{} |> Map.keys() |> length()) - 1
  @test_transformer Module.concat(Transformer, Test)
  defmodule @test_transformer, do: use(Transformer)

  setup :verify_on_exit!

  setup_all do
    first_time =
      DateTime.from_iso8601("2022-01-01T18:50:07Z")
      |> elem(1)
      |> DateTime.to_unix()

    latest =
      DateTime.from_iso8601("2023-04-03T18:50:07Z")
      |> elem(1)
      |> DateTime.to_unix()

    # archive with 16 months scrobbles: 2022 full year, 2023 up to Apr (4 months)
    metadata =
      build(:file_archive_metadata,
        creator: "a_lastfm_user",
        first_scrobble_time: first_time,
        latest_scrobble_time: latest
      )

    dataframe = dataframe()
    scrobbles_per_month = dataframe |> DataFrame.collect() |> DataFrame.n_rows()

    %{
      dataframe: dataframe,
      metadata: metadata,
      transformer: @test_transformer,
      scrobbles_per_month: scrobbles_per_month
    }
  end

  describe "source/2" do
    test "scrobbles into data frame", %{
      dataframe: df,
      metadata: metadata,
      transformer: transformer,
      scrobbles_per_month: scrobbles_per_month
    } do
      options = []

      # lazy data frame is built upon 16 months (reads) of data
      FileArchiveMock |> expect(:read, 16, fn ^metadata, _options -> {:ok, df} end)

      assert capture_log(fn ->
               assert %DataFrame{} = df = transformer.source(metadata, options)
               assert df |> DataFrame.collect() |> DataFrame.shape() == {16 * scrobbles_per_month, @column_count}
             end) =~ "Sourcing scrobbles"
    end

    test "with year option", %{
      dataframe: df,
      metadata: metadata,
      transformer: transformer,
      scrobbles_per_month: scrobbles_per_month
    } do
      options = [year: 2023]

      # only read the 4 months data in 2023
      FileArchiveMock |> expect(:read, 4, fn ^metadata, _options -> {:ok, df} end)

      capture_log(fn ->
        assert %DataFrame{} = df = transformer.source(metadata, options)
        assert df |> DataFrame.collect() |> DataFrame.shape() == {4 * scrobbles_per_month, @column_count}
      end)
    end

    # need to consider consistency vs. availability trade off later
    test "return partial dataset when a read returns error", %{
      dataframe: df,
      metadata: metadata,
      transformer: transformer,
      scrobbles_per_month: scrobbles_per_month
    } do
      options = [year: 2023]

      FileArchiveMock
      |> expect(:read, 4, fn ^metadata, option ->
        case Keyword.get(option, :month) do
          ~D[2023-04-01] -> {:error, :inval}
          _ -> {:ok, df}
        end
      end)

      capture_log(fn ->
        assert %DataFrame{} = df = transformer.source(metadata, options)
        # 3 instead of 4 months data
        assert df |> DataFrame.collect() |> DataFrame.shape() == {3 * scrobbles_per_month, @column_count}
      end)
    end
  end

  describe "sink/3" do
    setup context do
      FileArchiveMock
      |> expect(:read, 12, fn _, _ -> {:ok, context.dataframe |> DataFrame.mutate(year: 2022)} end)
      |> expect(:read, 4, fn _, _ -> {:ok, context.dataframe |> DataFrame.mutate(year: 2023)} end)

      %{csv_data: scrobbles_csv_gzipped()}
    end

    test "into csv files", %{
      csv_data: csv_data,
      metadata: %{creator: user} = metadata,
      scrobbles_per_month: scrobbles_per_month,
      transformer: transformer
    } do
      format = :csv
      options = [format: format]
      write_opts = Transformer.write_opts(format)
      archive_dir = "#{options |> validate_opts() |> derived_archive_dir()}"

      filepath = Path.join([user_dir(user), archive_dir, "2022.#{format}.gz"])

      FileIOMock
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      filepath = Path.join([user_dir(user), archive_dir, "2023.#{format}.gz"])

      FileIOMock
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^write_opts ->
        # 2022, 12 months scrobbles
        assert df |> DataFrame.shape() == {12 * scrobbles_per_month, @column_count}
        csv_data
      end)
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^write_opts ->
        # 2023, 4 months scrobbles
        assert df |> DataFrame.shape() == {4 * scrobbles_per_month, @column_count}
        csv_data
      end)

      assert capture_log(fn ->
               df = transformer.source(metadata, options)
               assert :ok = transformer.sink(df, metadata, options)
             end) =~ "Writing data"
    end

    for format <- Transformer.formats() do
      if format != :csv do
        test "into #{format} files", %{
          metadata: %{creator: user} = metadata,
          scrobbles_per_month: scrobbles_per_month,
          transformer: transformer
        } do
          format = unquote(format)
          options = [format: format]
          write_opts = Transformer.write_opts(format)
          archive_dir = "#{options |> validate_opts() |> derived_archive_dir()}"

          filepath1 = Path.join([user_dir(user), archive_dir, "2022.#{format}"])
          filepath2 = Path.join([user_dir(user), archive_dir, "2023.#{format}"])

          FileIOMock
          |> expect(:exists?, fn ^filepath1 -> false end)
          |> expect(:exists?, fn ^filepath2 -> false end)

          DataFrameMock
          |> expect(:"to_#{format}!", fn %DataFrame{} = df, ^filepath1, ^write_opts ->
            # 2022, 12 months scrobbles
            assert df |> DataFrame.shape() == {12 * scrobbles_per_month, @column_count}
            :ok
          end)
          |> expect(:"to_#{format}!", fn %DataFrame{} = df, ^filepath2, ^write_opts ->
            # 2023, 4 months scrobbles
            assert df |> DataFrame.shape() == {4 * scrobbles_per_month, @column_count}
            :ok
          end)

          assert capture_log(fn ->
                   df = transformer.source(metadata, options)
                   assert :ok = transformer.sink(df, metadata, options)
                 end) =~ "Writing data"
        end
      end

      test "does not overwrite existing #{format} files", %{
        csv_data: csv_data,
        metadata: metadata,
        transformer: transformer
      } do
        format = unquote(format)
        options = [format: format]
        write_opts = Transformer.write_opts(format)

        FileIOMock
        |> stub(:exists?, fn _filepath -> true end)
        |> expect(:write, 0, fn __filepath, _data, [:compressed] -> :ok end)

        DataFrameMock
        |> expect(:"dump_#{format}!", 0, fn _df, ^write_opts -> csv_data end)
        |> expect(:"to_#{format}!", 0, fn _df, _filepath, ^write_opts -> :ok end)

        assert capture_log(fn ->
                 df = transformer.source(metadata, options)
                 assert :ok = transformer.sink(df, metadata, options)
               end) =~ "Skipping"
      end

      test "overwrites existing #{format} files when opted", %{
        csv_data: csv_data,
        metadata: metadata,
        transformer: transformer
      } do
        format = unquote(format)
        options = [format: format, overwrite: true]
        write_opts = Transformer.write_opts(format)

        FileIOMock
        |> expect(:exists?, 2, fn _filepath -> true end)

        if format == :csv do
          FileIOMock |> expect(:write, 2, fn __filepath, _data, [:compressed] -> :ok end)

          DataFrameMock
          |> expect(:"dump_#{format}!", 2, fn %DataFrame{}, ^write_opts -> csv_data end)
        else
          DataFrameMock
          |> expect(:"to_#{format}!", 2, fn %DataFrame{}, _filepath, ^write_opts -> :ok end)
        end

        capture_log(fn ->
          df = transformer.source(metadata, options)
          assert :ok = transformer.sink(df, metadata, options)
        end)
      end
    end
  end

  describe "apply/3" do
    test "transform all years", %{dataframe: df, metadata: metadata, transformer: transformer} do
      options = [format: :ipc_stream]
      archive_dir = "#{options |> validate_opts() |> derived_archive_dir()}"
      dir = Path.join(user_dir(metadata.creator), archive_dir)

      FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:exists?, 2, fn _filepath -> false end)

      # source 2-year, 16 months scrobbles data
      FileArchiveMock |> expect(:read, 16, fn ^metadata, _options -> {:ok, df} end)
      # sink scrobbles into 2 (years) files
      DataFrameMock |> expect(:to_ipc_stream!, 2, fn _df, _filepath, _write_opts -> :ok end)

      capture_log(fn ->
        assert {:ok, %LastfmArchive.Archive.Metadata{}} = Transformer.apply(transformer, metadata, options)
      end)
    end

    test "transform a given year", %{dataframe: df, metadata: metadata, transformer: transformer} do
      options = [format: :ipc_stream, year: 2022]
      archive_dir = "#{options |> validate_opts() |> derived_archive_dir()}"
      dir = Path.join(user_dir(metadata.creator), archive_dir)
      filepath = "#{dir}/2022.ipc_stream"

      FileIOMock
      |> expect(:exists?, fn ^dir -> true end)
      |> expect(:exists?, fn ^filepath -> false end)

      # source 1-year, 12 months scrobbles data
      FileArchiveMock |> expect(:read, 12, fn ^metadata, _options -> {:ok, df} end)
      # sink scrobbles into single years file
      DataFrameMock |> expect(:to_ipc_stream!, fn _df, _filepath, _write_opts -> :ok end)

      capture_log(fn ->
        assert {:ok, %LastfmArchive.Archive.Metadata{}} = Transformer.apply(transformer, metadata, options)
      end)
    end
  end
end
