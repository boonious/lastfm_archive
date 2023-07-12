import Config

# Lastfm user for the archive
config :lastfm_archive,
  data_dir: "./lastfm_data/",
  interval: 1000,
  lastfm_api_key: "",
  lastfm_client: LastfmArchive.LastfmClient.Impl,
  per_page: 200,
  file_archive: LastfmArchive.Archive.FileArchive,
  user: ""

config :lastfm_archive,
  file_archive: LastfmArchive.Archive.FileArchive,
  derived_archive: LastfmArchive.Archive.DerivedArchive

config :lastfm_archive,
  cache: LastfmArchive.Cache,
  data_frame_io: Explorer.DataFrame,
  file_io: Elixir.File,
  path_io: Elixir.Path

config :lastfm_archive, :file_archive_transformer,
  format_settings: %{
    csv: {"text/tab-separated-values", [delimiter: "\t"]},
    parquet: {"application/vnd.apache.parquet", []}
  }

# optional: Solr endpoint for Lastfm data loading
config :hui, :lastfm_archive,
  url: "http://localhost:8983/solr/lastfm_archive",
  handler: "update",
  headers: [{"Content-type", "application/json"}]

config :logger, level: :info

import_config("#{config_env()}.exs")

# provides the above (private) credentails for local dev/testing purposes in lastfm.secret.exs
if File.exists?("./config/lastfm.secret.exs"), do: import_config("lastfm.secret.exs")
