# Changelog

## v0.2.5 (2021-12-20)
  * Bump minimum Elixir version to v1.10
  * Bump dependencies

## v0.2.4 (2021-09-16)
  * Bump dependencies
  * DefaultFetcher - return empty string from for_scope error (#140)

## v0.2.3 (2019-12-21)
  * Fixed missing alias for Goth.Token module (#101)

## v0.2.2 (2019-12-21)
  * Use GitHub Actions (#88)
  * Add test coverage tool (#90)
  * Allow upload with no ACL (#98)
  * Fix various compile warnings (#100)
  * Configurable token generation (#97)
  * Bump dependencies

## v0.2.1 (2019-12-21)
  * Bump dependencies

## v0.2.0 (2019-12-09)
  * Switch from SweetXML to the official Google Cloud API library
  * Bump dependencies

## v0.1.2 (2019-02-26)
  * Change from `seconds` to `second`

## v0.1.1 (2019-02-12)
  * Bump dependencies

## v0.1.0 (2018-10-02)
  * (Enhancement) Allow overriding the destination bucket in an upload definition. See (https://github.com/martide/arc_gcs/pull/45)
  * (Enhancement) Allow overriding the `storage_dir` via configuration. See (https://github.com/martide/arc_gcs/pull/43)
  * (Enhancement) Allow optional `expires_in` when signing an url. See (https://github.com/martide/arc_gcs/pull/41)
  * (Breaking Change) Now `config :arc, :bucket` is mandatory.
  * (Bugfix) Fix spaces on filename. See (https://github.com/martide/arc_gcs/pull/47)
