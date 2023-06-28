import Config

# Lastfm user for the archive
config :lastfm_archive,
  data_dir: "./lastfm_data/test/",
  interval: 1,
  lastfm_api_key: "",
  lastfm_client: LastfmArchive.LastfmClientMock,
  per_page: 200,
  type: LastfmArchive.Archive.FileArchiveMock,
  user: "test_user"

config :lastfm_archive,
  cache: LastfmArchive.CacheMock,
  data_frame_io: Explorer.DataFrameMock,
  file_io: LastfmArchive.FileIOMock,
  path_io: LastfmArchive.PathIOMock

config :logger,
  level: :info
