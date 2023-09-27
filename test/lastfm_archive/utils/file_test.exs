defmodule LastfmArchive.Utils.FileTest do
  use ExUnit.Case, async: true

  alias LastfmArchive.Archive.Metadata
  alias LastfmArchive.FileIOMock
  alias LastfmArchive.Utils.File, as: FileUtils

  import ExUnit.CaptureLog
  import Hammox
  import LastfmArchive.Factory, only: [build: 1, build: 2, scrobbles_csv_gzipped: 0]
  import LastfmArchive.Utils.Archive, only: [metadata_filepath: 2, user_dir: 1]

  setup :verify_on_exit!

  setup_all do
    user = "utils_test_user"

    %{
      user: user,
      user_dir: user_dir(user),
      metadata: build(:file_archive_metadata, creator: user),
      metadata_filepath: metadata_filepath(user, []),
      scrobbles: build(:recent_tracks)
    }
  end

  describe "ls_archive_files/2" do
    test "for a specified day", %{user: user, user_dir: user_dir} do
      filepath = "#{user_dir}/2023/06/01"
      files = ["200_001.gz", "200_002.gz", ".DS_Store", "another_file"]

      LastfmArchive.FileIOMock |> expect(:ls!, fn ^filepath -> files end)
      assert FileUtils.ls_archive_files(user, day: ~D[2023-06-01]) == ["2023/06/01/200_001.gz", "2023/06/01/200_002.gz"]
    end

    test "for a specified month", %{user: user, user_dir: user_dir} do
      wildcard_path = "#{user_dir}/2023/06/**/*.gz"
      files = ["#{user_dir}/2023/06/01/200_001.gz", "#{user_dir}/2023/06/02/200_001.gz"]

      LastfmArchive.PathIOMock |> expect(:wildcard, fn ^wildcard_path, _options -> files end)

      assert FileUtils.ls_archive_files(user, month: ~D[2023-06-01]) == [
               "2023/06/01/200_001.gz",
               "2023/06/02/200_001.gz"
             ]
    end
  end

  describe "read/1" do
    test "gzipped archive file for a given user and file location", %{user_dir: user_dir} do
      csv_file = Path.join(user_dir, "csv/2018.csv.gz")

      FileIOMock |> expect(:read, fn ^csv_file -> {:ok, scrobbles_csv_gzipped()} end)

      assert {:ok, resp} = FileUtils.read(csv_file)
      [_header | scrobbles] = resp |> String.split("\n")
      assert length(scrobbles) > 0
    end

    test "returns error on file not exists", %{user_dir: user_dir} do
      non_existing_file = Path.join(user_dir, "non_existing_file.csv.gz")
      FileIOMock |> expect(:read, fn ^non_existing_file -> {:error, :enoent} end)
      capture_log(fn -> assert {:error, :enoent} = FileUtils.read(non_existing_file) end)
    end
  end

  describe "write/2 metadata" do
    test "to a file", %{metadata: metadata, metadata_filepath: path} do
      dir = path |> Path.dirname()
      metadata_encoded = metadata |> Jason.encode!()

      FileIOMock
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^path, ^metadata_encoded -> :ok end)

      assert {:ok, %Metadata{created: created}} = FileUtils.write(metadata, [])
      assert %DateTime{} = created
    end

    test "returns file io error", %{metadata: metadata} do
      FileIOMock
      |> expect(:mkdir_p, fn _metadata_dir -> :ok end)
      |> expect(:write, fn _path, _metadata -> {:error, :einval} end)

      assert {:error, :einval} = FileUtils.write(metadata, [])
    end
  end

  describe "write/3 raw scrobbles data" do
    setup context do
      path = "2021/12/31/200_001"
      %{filepath: Path.join(context.user_dir, "#{path}.gz"), path: path}
    end

    test "to a file", %{filepath: full_path, path: path, metadata: metadata, scrobbles: scrobbles} do
      dir = full_path |> Path.dirname()
      scrobbles_encoded = scrobbles |> Jason.encode!()

      FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^full_path, ^scrobbles_encoded, [:compressed] -> :ok end)

      assert :ok == FileUtils.write(metadata, scrobbles, filepath: path)
    end

    test "handles api error", context do
      api_error_message = "Operation failed - Something went wrong"

      assert {:error, ^api_error_message} =
               FileUtils.write(context.metadata, {:error, api_error_message}, filepath: context.path)
    end

    test "when filepath option not given", %{filepath: path, metadata: metadata, scrobbles: scrobbles} do
      scrobbles_encoded = scrobbles |> Jason.encode!()

      FileIOMock
      |> expect(:exists?, 0, fn _metadata_filepath -> true end)
      |> expect(:write, 0, fn ^path, ^scrobbles_encoded, [:compressed] -> true end)

      assert_raise KeyError, fn ->
        FileUtils.write(metadata, scrobbles, [])
      end
    end
  end
end
