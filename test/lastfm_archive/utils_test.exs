defmodule LastfmArchive.UtilsTest do
  use ExUnit.Case, async: true

  import Hammox
  import Fixtures.Archive
  import Fixtures.Lastfm

  alias LastfmArchive.Utils
  alias LastfmArchive.Archive.Metadata

  test "metadata_filepath/2" do
    opts = []
    filepath = ".metadata/scrobbles/json_archive"
    assert Utils.metadata_filepath("user", opts) == "#{Utils.user_dir("user", opts)}/#{filepath}"

    opts = [format: :ipc_stream]
    filepath = ".metadata/scrobbles/ipc_stream_archive"
    assert Utils.metadata_filepath("user", opts) == "#{Utils.user_dir("user", opts)}/#{filepath}"

    opts = [format: :ipc_stream, facet: :artists]
    filepath = ".metadata/artists/ipc_stream_archive"
    assert Utils.metadata_filepath("user", opts) == "#{Utils.user_dir("user", opts)}/#{filepath}"
  end

  test "read/2 file from the archive for a given user and file location" do
    test_user = "load_test_user"
    csv_file = Path.join(Utils.user_dir("load_test_user"), "csv/2018.csv.gz")
    non_existing_file = Path.join(Utils.user_dir("load_test_user"), "non_existing_file.csv.gz")

    LastfmArchive.FileIOMock
    |> expect(:read, fn ^non_existing_file -> {:error, :enoent} end)
    |> expect(:read, fn ^csv_file -> {:ok, csv_gzip_data()} end)

    assert {:error, :enoent} = Utils.read(test_user, "non_existing_file.csv.gz")
    assert {:ok, resp} = Utils.read(test_user, "csv/2018.csv.gz")

    [_header | scrobbles] = resp |> String.split("\n")
    assert length(scrobbles) > 0
  end

  describe "write/2" do
    setup do
      user = "write_test_user"
      metadata = file_archive_metadata(user)
      %{metadata: metadata, metadata_filepath: Utils.metadata_filepath(user, [])}
    end

    test "metadata to a file", %{metadata: metadata, metadata_filepath: path} do
      dir = path |> Path.dirname()
      metadata_encoded = metadata |> Jason.encode!()

      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^path, ^metadata_encoded -> :ok end)

      assert {:ok, %Metadata{created: created}} = Utils.write(metadata, [])
      assert %DateTime{} = created
    end

    test "returns file io error", %{metadata: metadata} do
      LastfmArchive.FileIOMock
      |> expect(:mkdir_p, fn _metadata_dir -> :ok end)
      |> expect(:write, fn _path, _metadata -> {:error, :einval} end)

      assert {:error, :einval} = Utils.write(metadata, [])
    end
  end

  describe "write/3" do
    setup do
      user = "write_test_user"
      path = "2021/12/31/200_001"

      %{
        scrobbles: recent_tracks(user, 5) |> Jason.decode!(),
        filepath: Path.join(Utils.user_dir(user, []), "#{path}.gz"),
        path: path,
        user: user
      }
    end

    test "scrobbles to a file", %{user: user, scrobbles: scrobbles, filepath: full_path, path: path} do
      dir = full_path |> Path.dirname()
      scrobbles_encoded = scrobbles |> Jason.encode!()

      LastfmArchive.FileIOMock
      |> expect(:exists?, fn ^dir -> false end)
      |> expect(:mkdir_p, fn ^dir -> :ok end)
      |> expect(:write, fn ^full_path, ^scrobbles_encoded, [:compressed] -> :ok end)

      assert :ok == Utils.write(file_archive_metadata(user), scrobbles, filepath: path)
    end

    test "handles scrobbles retrieving error", context do
      api_error_message = "Operation failed - Something went wrong"

      assert {:error, ^api_error_message} =
               Utils.write(file_archive_metadata("test_user"), {:error, api_error_message}, filepath: context.path)
    end

    test "when filepath option not given", %{user: user, scrobbles: scrobbles, filepath: path} do
      scrobbles_encoded = scrobbles |> Jason.encode!()

      LastfmArchive.FileIOMock
      |> expect(:exists?, fn _metadata_filepath -> true end)
      |> expect(:write, 0, fn ^path, ^scrobbles_encoded, [:compressed] -> true end)

      assert_raise KeyError, fn ->
        Utils.write(file_archive_metadata(user), scrobbles, [])
      end
    end
  end

  describe "ls_archive_files/2" do
    test "for a specified day" do
      user = "a_lastfm_user"
      user_dir = Utils.user_dir(user)
      filepath = "#{user_dir}/2023/06/01"
      files = ["200_001.gz", "200_002.gz", ".DS_Store", "another_file"]

      LastfmArchive.FileIOMock |> expect(:ls!, fn ^filepath -> files end)
      assert Utils.ls_archive_files(user, day: ~D[2023-06-01]) == ["2023/06/01/200_001.gz", "2023/06/01/200_002.gz"]
    end

    test "for a specified month" do
      user = "a_lastfm_user"
      user_dir = Utils.user_dir(user)
      wildcard_path = "#{user_dir}/2023/06/**/*.gz"
      files = ["#{user_dir}/2023/06/01/200_001.gz", "#{user_dir}/2023/06/02/200_001.gz"]

      LastfmArchive.PathIOMock |> expect(:wildcard, fn ^wildcard_path, _options -> files end)

      assert Utils.ls_archive_files(user, month: ~D[2023-06-01]) == ["2023/06/01/200_001.gz", "2023/06/02/200_001.gz"]
    end
  end
end
