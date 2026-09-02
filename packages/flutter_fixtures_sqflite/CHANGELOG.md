# Changelog

## Unreleased

* **BREAKING**: `FixtureDatabaseAdapter` takes one `pipeline`
  (`FixturePipeline<SqfliteQuery>`) instead of `dataQuery` / `dataSelector`
  / `dataSelectorView` / `delay`. A cancelled pick now throws
  `FixtureCancelled` instead of silently returning the operation's default;
  not-found and empty still degrade to the default.

* **BREAKING**: `SqfliteFixtureSource` is now an alias for core's
  `FixtureSource<SqfliteQuery>`, so its lookup method is `resolve` (was
  `find`). `SqfliteDataQuery` is renamed `SqfliteFileFixtureSource` — core's
  `FixtureFileSource` with the sqflite naming convention — with a deprecated
  alias kept for one release.

* New `RecorderDatabaseAdapter`: a record-and-replay decorator over any
  `DatabaseAdapter`, capturing reads and mutations through core's
  `TrafficRecorder` seam (engine: `flutter_fixtures_recorder`). A
  replayed `insert` returns the recorded row id without writing anywhere.
  Statements are described and encoded lazily, so idle traffic costs
  nothing.
* `SqfliteQuery` is now the single statement-identity model: it carries
  every `DatabaseAdapter` field (arguments, values, modifiers) with two
  projections — `fixtureCandidates` (lossy fixture-file names, unchanged
  for table operations) and `recordingTarget` (total canonical JSON for
  record & replay). `SqfliteOperation` covers all eleven operations.
* **BREAKING**: raw writes and `execute` now use their own operation in
  fixture file names — `rawInsert_*`, `rawUpdate_*`, `rawDelete_*`,
  `execute_*` instead of collapsing to `rawQuery_*`. Rename affected
  fixture files.

* **BREAKING**: `SqfliteDataQuery` implements the new `SqfliteFixtureSource`
  seam (`find` returns a `FixtureCollection`, `data` returns the payload
  as-is): `parse` is gone (the wire format lives in core's models), list
  payloads are no longer wrapped in a `result` key, and `mockFolderPath`
  was removed (use `mockFolder`). `FixtureDatabaseAdapter.dataQuery` is
  typed as `SqfliteFixtureSource`, and the adapter drives core's
  `FixtureSelector.serve` pipeline instead of its own find → parse →
  select → data loop. Fixture files that wrap rows in a top-level
  `result` key keep working.
* **BREAKING**: the unused `SqfliteOperation.rawExecute` value was removed;
  raw statements resolve as `rawQuery` fixtures, as they always did.
* `SqfliteQuery.fixtureCandidates` owns the fixture-file candidate list
  (identifier first, bare `{operation}_{table}` fallback), so the naming
  convention lives in one place.
* `RealDatabaseAdapter` is covered by a conformance test against an
  in-memory SQLite database (`sqflite_common_ffi`).

## 0.2.0

* **BREAKING**: `FixtureDatabaseAdapter.dataQuery` is typed as `DataQuery<SqfliteQuery, Map<String, dynamic>>`, making the seam substitutable in tests.
* `SqfliteDataQuery` accepts an `assetLoader`, making `find` testable without a Flutter asset bundle.
* The six write operations share one execute path; inline fixture data no longer bypasses `dataQuery.data`.

## 0.1.2

* Align version with sibling implementation packages (dio, ui) for consistency
* No code changes

## 0.1.0

* Initial release
* SQLite/sqflite implementation of DataQuery interface
* `FixtureDatabase` class providing sqflite-like API (`query`, `insert`, `update`, `delete`, `rawQuery`)
* `SqfliteDataQuery` for loading database fixtures from assets
* `SqfliteQuery` model for table-based and raw SQL query matching
* Support for operations: query, insert, update, delete
* Compatible with flutter_fixtures_core ^0.1.2
