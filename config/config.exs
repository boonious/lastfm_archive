use Mix.Config

# Lastfm user for the archive
config :lastfm_archive, 
  user: "",
  data_dir: "./lastfm_data/",
  per_page: 200, # 200 is max permissable number of results per call
  interval: 500 # milliseconds between requests cf. Lastfm permissable max 5 reqs/s rate

# API key required to extract Lastfm data
# see: https://www.last.fm/api
config :elixirfm,
  lastfm_ws: "http://ws.audioscrobbler.com/",
  api_key: "",
  secret_key: ""

# provides the above (private) credentails for local dev/testing purposes in lastfm.secret.exs
if File.exists?("./config/lastfm.secret.exs"), do: import_config "lastfm.secret.exs"