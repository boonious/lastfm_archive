defmodule LastfmArchive.Archive.DerivedArchiveTest do
  use ExUnit.Case, async: true

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
        start: DateTime.from_iso8601("2023-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        end: DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix(),
        type: DerivedArchive
      )

    %{dir: Path.join(user_dir(user), "tsv"), user: user, metadata: metadata}
  end

  describe "after_archive/3" do
    test "transform FileArchive into TSV file", %{dir: dir, metadata: metadata, user: user} do
      filepath = Path.join([user_dir(user), "tsv", "2023.tsv.gz"])

      # 4 read for 4 months, each with 105 scrobbles
      FileArchiveMock
      |> expect(:read, 4, fn ^metadata, _option -> {:ok, test_data_frame()} end)

      FileIOMock
      |> expect(:exists?, fn ^dir -> true end)
      |> expect(:exists?, fn ^filepath -> false end)
      |> expect(:write, fn ^filepath, _data, [:compressed] -> :ok end)

      DataFrameMock
      |> expect(:dump_csv!, fn %DataFrame{} = df, [delimiter: "\t"] ->
        # 4 month of scrobbles
        assert df |> DataFrame.shape() == {4 * 105, 11}
        tsv_data()
      end)

      assert {:ok, _metadata} = DerivedArchive.after_archive(metadata, FileArchiveTransformer, format: :tsv)
    end
  end

  describe "read/2" do
    # stub test for now
    test "tsv derived archive", %{metadata: metadata} do
      assert {:ok, %DataFrame{}} = DerivedArchive.read(metadata, year: 2023)
    end
  end
end
