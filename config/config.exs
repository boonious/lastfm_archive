use Mix.Config

# Lastfm user for the archive
config :lastfm_archive, 
  user: "",
  data_dir: "./lastfm_data/",
  req_interval: 500 # milliseconds between requests cf. Lastfm permissable max 5 reqs/s rate

# API key required to extract Lastfm data
# see: https://www.last.fm/api
config :elixirfm,
  lastfm_ws: "http://ws.audioscrobbler.com/",
  api_key: "",
  secret_key: ""

# provides the above credentails for local dev/test purposes
if File.exists?("./config/lastfm.secret.exs"), do: import_config "lastfm.secret.exs"