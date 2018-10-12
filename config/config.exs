use Mix.Config

# Lastfm user for the archive
config :lastfm_archive, 
  user: ""

# API key required to extract Lastfm data
# see: https://www.last.fm/api
config :elixirfm,
  api_key: "",
  secret_key: ""

# provides the above credentails for local dev/test purposes
if File.exists?("./config/lastfm.secret.exs"), do: import_config "lastfm.secret.exs"