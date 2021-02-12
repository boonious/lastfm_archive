import Config

# Lastfm user for the archive
config :lastfm_archive,
  api: %{api_key: "", endpoint: "", method: ""},
  lastfm_client: Lastfm.ClientMock,
  user: "test_user",
  data_dir: "./lastfm_data/test/",
  per_page: 200,
  interval: 1

config :lastfm_archive, file_io: Lastfm.FileIOMock
