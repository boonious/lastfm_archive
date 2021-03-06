# Changelog

## 0.9.1 (2021-05-05)

* `sync/2` handles request errors from Last.fm API
* caches errors during sync so that subsequent syncs or API requests can be made to archive the missing scrobbles
* do not cache sync results of today's scrobbles as it's a always partial sync

## 0.9.0 (2021-04-14)

* Create an `Archive` behaviour with `FileArchive` implementation
* Extract and store scrobbles in daily chunks
* Extensive refactoring: simpler LastfmArchive functions core, deprecate `archive` functions
* Rewrite tests with mocks, eliminate file writes during tests
* Implement a GenServer simple tick-based (auto) cache memoization to prevent repetitive API calls to Last.fm

## 0.8.0 (2021-01-04)

* Update Elixir/Erlang versions and dependencies
* Replace HTTP client (HTTPoison) with Erlang's built-in httpc client
* Replace Poison with Jason for JSON decoding/encoding
* Apply mix formatting to the entire codebase
* Refactor and abstract LastfmArchive.Extract functions into a new module based on `Lastfm.Client` behaviour
* Implement explicit behaviour and contract-based unit testing (Hammox/Mox)
* Refactor and enable concurrent testing

## 0.7.2 (2019-02-25)

* Fix the issue of Last.fm changing the date/count data type in JSON back and forth (string <-> integer).

## 0.7.1 (2019-01-14)

* Patches as per Last.fm API JSON data format changes: uts timestamp, play counts info are now returned as integers instead of strings.

## 0.7.0 (2019-01-11)

* `sync/0`, `sync/1`: sync and keep tracks of scrobbles for a default and Last.fm users, via delta archiving (download latest scrobbles)

## 0.6.0 (2018-11-10)

* Support for Solr: load all transformed (TSV) data from the archive into Solr, `load_archive/2`
* Underpinning functions to read, parse, load data into Solr

## 0.5.0 (2018-11-05)

* `transform_archive/2`: transform downloaded raw Last.fm archive and create a TSV file archive
*  Underpinning functions to read, parse and transform raw Lastfm JSON data into TSV files

## 0.4.1 (2018-11-01)

* fix single year archiving (bug): `daily: true` option

## 0.4.0 (2018-10-31)

* `archive/3`: archiving data subset based on date ranges: single day/year, past week/month, arbitrary date range using `Date`, `Date.Range` structs
* `daily: true` option for finer-grained batch archiving cf. the default year-level granularity

## 0.3.2 (2018-10-27)

* `overwrite` archiving option to also re-fetch any existing downloaded data, for refreshing file archive

## 0.3.1 (2018-10-27)

* Keyword list archiving options (`per_page`, `interval`) for `archive/2` which can also be configured

## 0.3.0 (2018-10-26)

* `archive` latest tracks (current year) on a daily basis to better ensure data immutability and updatability (new scrobbles)
* `archive` older tracks on a yearly basis

## 0.2.0 (2018-10-23)

* `archive/0`: downloads scrobbled tracks, creates a file archive for a default user according to configuration settings
* `archive/2`: downloads scrobbled tracks, creates a file archive for any Lastfm user
* `write/3`: outputs data for multiple Lastfm users (no longer hardwired to the default user)

## 0.1.0 (2018-10-22)

* Download scrobbled tracks raw data, create an archive on local filesystem for a default user in configuration - `archive/1`
* `extract/5` and `write/2` functions for Lastfm API requests and file output
