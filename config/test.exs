import Config

# Lastfm user for the archive
config :lastfm_archive,
  data_dir: "./lastfm_data/test/",
  interval: 1,
  lastfm_api_key: "",
  lastfm_client: LastfmArchive.LastfmClientMock,
  per_page: 200,
  type: LastfmArchive.FileArchiveMock,
  user: "test_user"

config :lastfm_archive,
  cache: LastfmArchive.CacheMock,
  file_io: LastfmArchive.FileIOMock,
  path_io: LastfmArchive.PathIOMock

config :logger,
  level: :info
