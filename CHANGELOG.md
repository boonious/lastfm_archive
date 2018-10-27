# Changelog

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
