import Config

# Lastfm user for the archive
config :lastfm_archive,
  api: %{api_key: "", endpoint: "", method: ""},
  data_dir: "./lastfm_data/test/",
  interval: 1,
  lastfm_client: Lastfm.ClientMock,
  per_page: 200,
  type: Lastfm.FileArchiveMock,
  user: "test_user"

config :lastfm_archive,
  cache: LastfmArchive.CacheMock,
  file_io: Lastfm.FileIOMock,
  path_io: Lastfm.PathIOMock
