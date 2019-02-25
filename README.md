# Lastfm Archive [![Build Status](https://travis-ci.org/boonious/lastfm_archive.svg?branch=master)](https://travis-ci.org/boonious/lastfm_archive) [![Hex pm](http://img.shields.io/hexpm/v/lastfm_archive.svg?style=flat)](https://hex.pm/packages/lastfm_archive) [![Coverage Status](https://coveralls.io/repos/github/boonious/lastfm_archive/badge.svg)](https://coveralls.io/github/boonious/lastfm_archive?branch=master)

A tool for creating local Last.fm scrobble file archive, Solr archive and analytics.

The software is currently experimental and in preliminary development. It should
eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

## Current Usage

Download and create a file archive of Lastfm scrobble tracks via [Elixir](https://elixir-lang.org)
applications or [interactive Elixir](https://elixir-lang.org/getting-started/introduction.html#interactive-mode)
(invoking `iex -S mix` command line action while in software home directory).
 
```elixir
  # archive all data of a default user specified in configuration
  LastfmArchive.archive
  LastfmArchive.sync # subsequent calls download only latest scrobbles

  # archive all data of any Lastfm user
  # the data is stored in directory named after the user
  LastfmArchive.archive("a_lastfm_user")
  LastfmArchive.sync("a_lastfm_user") # subsequent calls download only latest scrobbles

  # archive a data subset
  LastfmArchive.archive("a_lastfm_user", :past_month)

  # data from year 2016
  LastfmArchive.archive("a_lastfm_user", 2016)

  # with Date struct
  LastfmArchive.archive("a_lastfm_user", ~D[2018-10-31])

  # with Date.Range struct and archiving options
  d1 = ~D[2018-01-01]
  d2 = d1 |> Date.add(7)
  LastfmArchive.archive("a_lastfm_user", Date.range(d1, d2), daily: true, overwrite: true)

```

Older scrobbles are archived on a yearly basis, whereas the latest (current year) scrobbles
are extracted on a daily basis to ensure data immutability and updatability.

The data is currently in raw Lastfm `recenttracks` JSON format,
chunked into 200-track (max) `gzip` compressed pages and stored within directories
corresponding to the years or days when tracks were scrobbled.

See [`archive/2`](https://hexdocs.pm/lastfm_archive/LastfmArchive.html#archive/2),
[`archive/3`](https://hexdocs.pm/lastfm_archive/LastfmArchive.html#archive/3) for more details
and archiving options.

The data is written to a main directory specified in configuration - see below.

To generate a TSV file archive from downloaded data:

```elixir
  # transform all data of a user into to TSV files
  LastfmArchive.transform_archive("a_lastfm_user")
```

See [`transform_archive/2`](https://hexdocs.pm/lastfm_archive/LastfmArchive.html#transform_archive/2).

### Loading data into Solr

To load all transformed TSV data from the archive into Solr:


```elixir
  # define a Solr endpoint with %Hui.URL{} struct
  headers = [{"Content-type", "application/json"}]
  url = %Hui.URL{url: "http://localhost:8983/solr/lastfm_archive", handler: "update", headers: headers}

  LastfmArchive.load_archive("a_lastfm_user", url)

  # use Solr endpoint from config setting - Configuration below
  LastfmArchive.load_archive("a_lastfm_user", :lastfm_archive)
```

The function finds TSV files from the archive and send them to
Solr for ingestion one at a time. It uses `Hui` client to interact
with Solr and the `t:Hui.URL.t/0` struct for Solr endpoint specification.

## Requirement

This tool requires Elixir and Erlang, see [installation](https://elixir-lang.org/install.html) details
for various operating systems.

## Installation

`lastfm_archive` is [available in Hex](https://hex.pm/packages/lastfm_archive),
the package can be installed by adding `lastfm_archive`
to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [
      {:lastfm_archive, "~> 0.7.2"}
    ]
  end
```

Documentation can be found at [https://hexdocs.pm/lastfm_archive](https://hexdocs.pm/lastfm_archive).

## Configuration
Add the following entries in your config - `config/config.exs`. For example,
the following specifies a `default_user` and a main file location for
multiple user archives, `./lastfm_data/` relative to the software home directory.

```elixir
  config :lastfm_archive, 
    user: "default_user", # the default user
    data_dir: "./lastfm_data/", # main directory for multiple archives
    per_page: 200, # 200 is max no. of tracks per call permitted by Lastfm API 
    interval: 500 # milliseconds between requests cf. Lastfm's max 5 reqs/s rate limit

  config :elixirfm,
    lastfm_ws: "http://ws.audioscrobbler.com/",
    api_key: "", # mandatory
    secret_key: ""

  # optional: Solr endpoint for Lastfm data loading
  config :hui, :lastfm_archive,
    url: "http://localhost:8983/solr/lastfm_archive",
    handler: "update",
    headers: [{"Content-type", "application/json"}]

```

See [`archive/2`](https://hexdocs.pm/lastfm_archive/LastfmArchive.html#archive/2)
for other configurable archiving options, e.g. `interval`, `per_page`.

See [`Hui`](https://hexdocs.pm/hui/readme.html#content) for more details on Solr configuration.

An `api_key` must be configured to enable Lastfm API requests,
see [https://www.last.fm/api](https://www.last.fm/api) ("Get an API account").


