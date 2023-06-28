defmodule LastfmArchive.Archive.Transformers.FileArchiveTransformerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Fixtures.Archive
  import Hammox
  import LastfmArchive.Utils, only: [user_dir: 1]

  alias LastfmArchive.Archive.FileArchiveMock
  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.Archive.Transformers.FileArchiveTransformer
  alias LastfmArchive.FileIOMock

  alias Explorer.DataFrameMock

  setup :verify_on_exit!

  setup do
    user = "a_lastfm_user"
    total_scrobbles = 400
    registered_time = DateTime.from_iso8601("2022-01-01T18:50:07Z") |> elem(1) |> DateTime.to_unix()
    last_scrobble_time = DateTime.from_iso8601("2023-04-03T18:50:07Z") |> elem(1) |> DateTime.to_unix()

    metadata = %{
      Metadata.new(user)
      | temporal: {registered_time, last_scrobble_time},
        extent: total_scrobbles,
        date: ~D[2021-04-03],
        type: FileArchive
    }

    FileArchiveMock
    |> stub(:describe, fn ^user, _options -> {:ok, metadata} end)
    |> stub(:read, fn ^metadata, _option -> {:ok, test_data_frame()} end)

    %{dir: Path.join(user_dir(user), "tsv"), user: user, metadata: metadata}
  end

  describe "apply/3" do
    test "TSV trasnformation", %{dir: dir, user: user, metadata: metadata} do
      filepath1 = Path.join([user_dir(user), "tsv", "2022.tsv.gz"])
      filepath2 = Path.join([user_dir(user), "tsv", "2023.tsv.gz"])

      FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:exists?, fn ^filepath1 -> false end)
      |> expect(:exists?, fn ^filepath2 -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)

      DataFrameMock
      |> expect(:to_csv, fn _df, ^filepath1, [delimiter: "\t"] -> :ok end)
      |> expect(:to_csv, fn _df, ^filepath2, [delimiter: "\t"] -> :ok end)

      assert capture_log(fn -> assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: :tsv) end) =~ "Creating"
    end

    test "does not overwrite existing TSV file", %{dir: dir, metadata: metadata} do
      FileIOMock
      |> expect(:exists?, fn ^dir -> true end)
      |> stub(:exists?, fn _filepath -> true end)

      DataFrameMock
      |> expect(:to_csv, 0, fn _df, _filepath, [delimiter: "\t"] -> :ok end)

      assert capture_log(fn -> assert {:ok, _} = FileArchiveTransformer.apply(metadata, format: :tsv) end) =~ "skipping"
    end
  end
end
