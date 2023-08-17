defmodule LastfmArchive.Archive.Transformers.TransformerTest do
  use ExUnit.Case

  alias Explorer.DataFrame
  alias Explorer.DataFrameMock

  alias LastfmArchive.Archive.FileArchiveMock
  alias LastfmArchive.Archive.Transformers.Transformer
  alias LastfmArchive.FileIOMock

  import ExUnit.CaptureLog
  import Hammox
  import Fixtures.Archive
  import LastfmArchive.Utils, only: [user_dir: 1]

  require Explorer.DataFrame

  @column_count (%LastfmArchive.Archive.Scrobble{} |> Map.keys() |> length()) - 1

  @test_transformer Module.concat(Transformer, Test)
  defmodule @test_transformer, do: use(Transformer)

  setup :verify_on_exit!

  setup do
    user = "a_lastfm_user"

    # archive  with 16 months scrobbles
    metadata =
      new_archive_metadata(
        user: user,
        start: DateTime.from_iso8601("2022-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: FileArchive,
        date: ~D[2023-04-03]
      )

    num_scrobbles_per_month = data_frame() |> DataFrame.collect() |> DataFrame.n_rows()
    %{metadata: metadata, transformer: @test_transformer, num_scrobbles_per_month: num_scrobbles_per_month}
  end

  describe "source/2" do
    test "scrobbles into dataframes", %{
      metadata: metadata,
      transformer: transformer,
      num_scrobbles_per_month: scrobbles_per_month
    } do
      options = []
      FileArchiveMock |> expect(:read, 16, fn ^metadata, _options -> {:ok, data_frame()} end)

      assert capture_log(fn ->
               assert %DataFrame{} = df = transformer.source(metadata, options)
               assert df |> DataFrame.collect() |> DataFrame.shape() == {16 * scrobbles_per_month, @column_count}
             end) =~ "Sourcing scrobbles"
    end

    test "with year option", %{
      metadata: metadata,
      transformer: transformer,
      num_scrobbles_per_month: scrobbles_per_month
    } do
      options = [year: 2023]

      # read 4 months of scrobbles in 2023
      FileArchiveMock |> expect(:read, 4, fn ^metadata, _options -> {:ok, data_frame()} end)

      capture_log(fn ->
        assert %DataFrame{} = df = transformer.source(metadata, options)
        assert df |> DataFrame.collect() |> DataFrame.shape() == {4 * scrobbles_per_month, @column_count}
      end)
    end

    test "when a read returns error", %{
      metadata: metadata,
      transformer: transformer,
      num_scrobbles_per_month: scrobbles_per_month
    } do
      options = [year: 2023]

      FileArchiveMock
      |> expect(:read, 4, fn ^metadata, option ->
        case Keyword.get(option, :month) do
          ~D[2023-04-01] -> {:error, :inval}
          _ -> {:ok, data_frame()}
        end
      end)

      capture_log(fn ->
        assert %DataFrame{} = df = transformer.source(metadata, options)
        assert df |> DataFrame.collect() |> DataFrame.shape() == {3 * scrobbles_per_month, @column_count}
      end)
    end
  end

  describe "sink/3" do
    setup do
      FileArchiveMock
      |> expect(:read, 12, fn _, _ -> {:ok, data_frame() |> DataFrame.mutate(year: 2022)} end)
      |> expect(:read, 4, fn _, _ -> {:ok, data_frame() |> DataFrame.mutate(year: 2023)} end)

      :ok
    end

    test "into csv files", %{metadata: %{creator: user} = metadata, transformer: transformer} do
      format = :csv
      options = [format: format]
      write_opts = Transformer.write_opts(format)

      dir = Path.join(user_dir(user), "#{format}")

      FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)

      filepath = Path.join([user_dir(user), "#{format}", "2022.#{format}.gz"])

      FileIOMock
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      filepath = Path.join([user_dir(user), "#{format}", "2023.#{format}.gz"])

      FileIOMock
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^write_opts ->
        # 2022, 12 months scrobbles
        assert df |> DataFrame.shape() == {12 * 105, @column_count}
        transformed_file_data(format)
      end)
      |> expect(:"dump_#{format}!", fn %DataFrame{} = df, ^write_opts ->
        # 2023, 4 months scrobbles
        assert df |> DataFrame.shape() == {4 * 105, @column_count}
        transformed_file_data(format)
      end)

      assert capture_log(fn ->
               df = transformer.source(metadata, options)
               assert {:ok, _} = transformer.sink(df, metadata, options)
             end) =~ "Sinking data"
    end

    for format <- Transformer.formats() do
      if format != :csv do
        test "into #{format} files", %{
          metadata: %{creator: user} = metadata,
          num_scrobbles_per_month: scrobbles_per_month,
          transformer: transformer
        } do
          format = unquote(format)
          options = [format: format]
          write_opts = Transformer.write_opts(format)
          dir = Path.join(user_dir(user), "#{format}")

          filepath1 = Path.join([user_dir(user), "#{format}", "2022.#{format}"])
          filepath2 = Path.join([user_dir(user), "#{format}", "2023.#{format}"])

          FileIOMock
          |> expect(:exists?, fn ^dir -> false end)
          |> expect(:mkdir_p, fn ^dir -> :ok end)
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
                   assert {:ok, _} = transformer.sink(df, metadata, options)
                 end) =~ "Sinking data"
        end
      end

      test "does not overwrite existing #{format} files", %{
        metadata: %{creator: user} = metadata,
        transformer: transformer
      } do
        format = unquote(format)
        options = [format: format]
        write_opts = Transformer.write_opts(format)
        dir = Path.join(user_dir(user), "#{format}")

        FileIOMock
        |> expect(:exists?, fn ^dir -> true end)
        |> stub(:exists?, fn _filepath -> true end)
        |> expect(:write, 0, fn __filepath, _data, [:compressed] -> :ok end)

        DataFrameMock
        |> expect(:"dump_#{format}!", 0, fn _df, ^write_opts -> transformed_file_data(format) end)
        |> expect(:"to_#{format}!", 0, fn _df, _filepath, ^write_opts -> :ok end)

        assert capture_log(fn ->
                 df = transformer.source(metadata, options)
                 assert {:ok, _} = transformer.sink(df, metadata, options)
               end) =~ "skipping"
      end

      test "overwrites existing #{format} files when opted", %{metadata: metadata, transformer: transformer} do
        format = unquote(format)
        options = [format: format, overwrite: true]
        write_opts = Transformer.write_opts(format)

        FileIOMock
        |> expect(:exists?, fn _dir -> true end)
        |> expect(:exists?, 2, fn _filepath -> true end)

        if format == :csv do
          FileIOMock |> expect(:write, 2, fn __filepath, _data, [:compressed] -> :ok end)

          DataFrameMock
          |> expect(:"dump_#{format}!", 2, fn %DataFrame{}, ^write_opts -> transformed_file_data(format) end)
        else
          DataFrameMock
          |> expect(:"to_#{format}!", 2, fn %DataFrame{}, _filepath, ^write_opts -> :ok end)
        end

        capture_log(fn ->
          df = transformer.source(metadata, options)
          assert {:ok, _} = transformer.sink(df, metadata, options)
        end)
      end
    end
  end
end
