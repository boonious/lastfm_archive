import Config

# Lastfm user for the archive
config :lastfm_archive,
  api: %{api_key: "", endpoint: "", method: ""},
  user: "",
  data_dir: "./lastfm_data/",
  # 200 is max permissable number of results per call
  per_page: 200,
  # milliseconds between requests cf. Lastfm permissable max 5 reqs/s rate
  interval: 500

# API key required to extract Lastfm data
# see: https://www.last.fm/api
config :elixirfm,
  lastfm_ws: "http://ws.audioscrobbler.com/",
  api_key: "",
  secret_key: ""

# optional: Solr endpoint for Lastfm data loading
config :hui, :lastfm_archive,
  url: "http://localhost:8983/solr/lastfm_archive",
  handler: "update",
  headers: [{"Content-type", "application/json"}]

# provides the above (private) credentails for local dev/testing purposes in lastfm.secret.exs
if File.exists?("./config/lastfm.secret.exs"), do: import_config("lastfm.secret.exs")
