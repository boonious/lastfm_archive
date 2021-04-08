import Config

# Lastfm user for the archive
config :lastfm_archive,
  api: %{api_key: "", endpoint: "", method: ""},
  data_dir: "./lastfm_data/",
  interval: 1000,
  lastfm_client: Lastfm.Extract,
  per_page: 200,
  type: Lastfm.FileArchive,
  user: ""

config :lastfm_archive, file_io: Elixir.File

# optional: Solr endpoint for Lastfm data loading
config :hui, :lastfm_archive,
  url: "http://localhost:8983/solr/lastfm_archive",
  handler: "update",
  headers: [{"Content-type", "application/json"}]

import_config("#{config_env()}.exs")

# provides the above (private) credentails for local dev/testing purposes in lastfm.secret.exs
if File.exists?("./config/lastfm.secret.exs"), do: import_config("lastfm.secret.exs")
