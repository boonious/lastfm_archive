import Config

# Lastfm user for the archive
config :lastfm_archive,
  api: %{api_key: "", endpoint: "", method: ""},
  lastfm_client: Lastfm.Extract,
  user: "",
  data_dir: "./lastfm_data/",
  # 200 is max permissable number of results per call
  per_page: 200,
  # milliseconds between requests cf. Lastfm permissable max 5 reqs/s rate
  interval: 500

# optional: Solr endpoint for Lastfm data loading
config :hui, :lastfm_archive,
  url: "http://localhost:8983/solr/lastfm_archive",
  handler: "update",
  headers: [{"Content-type", "application/json"}]

import_config("#{config_env()}.exs")

# provides the above (private) credentails for local dev/testing purposes in lastfm.secret.exs
if File.exists?("./config/lastfm.secret.exs"), do: import_config("lastfm.secret.exs")
