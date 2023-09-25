defmodule LastfmArchive.Utils.ArchiveTest do
  use ExUnit.Case, async: true

  import Hammox
  import LastfmArchive.Factory, only: [build: 1, build: 2]

  alias LastfmArchive.Utils.Archive, as: ArchiveUtils

  setup :verify_on_exit!

  setup_all do
    user = "utils_test_user"

    %{
      user: user,
      metadata: build(:file_archive_metadata, creator: user),
      metadata_filepath: ArchiveUtils.metadata_filepath(user, []),
      scrobbles: build(:recent_tracks)
    }
  end

  test "metadata_filepath/2" do
    opts = []
    filepath = ".metadata/scrobbles/json_archive"
    assert ArchiveUtils.metadata_filepath("user", opts) == "#{ArchiveUtils.user_dir("user", opts)}/#{filepath}"

    opts = [format: :ipc_stream]
    filepath = ".metadata/scrobbles/ipc_stream_archive"
    assert ArchiveUtils.metadata_filepath("user", opts) == "#{ArchiveUtils.user_dir("user", opts)}/#{filepath}"

    opts = [format: :ipc_stream, facet: :artists]
    filepath = ".metadata/artists/ipc_stream_archive"
    assert ArchiveUtils.metadata_filepath("user", opts) == "#{ArchiveUtils.user_dir("user", opts)}/#{filepath}"
  end
end
