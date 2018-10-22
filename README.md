# Lastfm Archive [![Build Status](https://travis-ci.org/boonious/lastfm_archive.svg?branch=master)](https://travis-ci.org/boonious/lastfm_archive) [![Hex pm](http://img.shields.io/hexpm/v/lastfm_archive.svg?style=flat)](https://hex.pm/packages/lastfm_archive) [![Coverage Status](https://coveralls.io/repos/github/boonious/lastfm_archive/badge.svg?branch=master)](https://coveralls.io/github/boonious/lastfm_archive?branch=master)

A tool for creating local Last.fm scrobble data archive and analytics.

The software is currently experimental and in preliminary development. It should
eventually provide capability to perform ETL and analytic tasks on Lastfm scrobble data.

## Current Usage

Download and create a file archive of Lastfm scrobble tracks for a configured user via [Elixir](https://elixir-lang.org)
applications or [interactive Elixir](https://elixir-lang.org/getting-started/introduction.html#interactive-mode)
(invoking `iex -S mix` command line action while in software home directory).
 
```elixir
  LastfmArchive.archive
```

The data is currently in raw Lastfm `recenttracks` JSON format,
chunked into 200-track compressed (gzip) pages and stored within directories
corresponding to the years when tracks were scrobbled.

The data is written to a main directory specified in configuration - see below.

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
      {:lastfm_archive, "~> 0.1.0"}
    ]
  end
```

Documentation can be found at [https://hexdocs.pm/lastfm_archive](https://hexdocs.pm/lastfm_archive).

## Configuration
Add the following entries in your config - `config/config.exs`. For example,
the following will create a file archive for `a_user`. The archive will be written to
`./lastfm_data/a_user/` within the software home directory.

An `api_key` must be configured to enable Lastfm API requests,
see [https://www.last.fm/api](https://www.last.fm/api) ("Get an API account").

```elixir
  config :lastfm_archive, 
    user: "a_user", # lastfm user name
    data_dir: "./lastfm_data/", # main directory for the archive
    per_page: 200, # 200 is max no. of tracks per call permitted by Lastfm API 
    req_interval: 500 # milliseconds between requests cf. Lastfm's max 5 reqs/s rate

  config :elixirfm,
    lastfm_ws: "http://ws.audioscrobbler.com/",
    api_key: "", # mandatory
    secret_key: ""

```