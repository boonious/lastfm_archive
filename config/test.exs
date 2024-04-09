import Config

config :lastfm_archive,
  data_dir: "./lastfm_data/test/",
  interval: 1,
  lastfm_client: LastfmArchive.LastfmClientMock,
  per_page: 200,
  user: "test_user"

config :lastfm_archive,
  file_archive: LastfmArchive.Archive.FileArchiveMock,
  derived_archive: LastfmArchive.Archive.DerivedArchiveMock

config :lastfm_archive,
  cache: LastfmArchive.CacheMock,
  data_frame_io: Explorer.DataFrameMock,
  file_io: LastfmArchive.FileIOMock,
  path_io: LastfmArchive.PathIOMock

config :logger,
  level: :info
