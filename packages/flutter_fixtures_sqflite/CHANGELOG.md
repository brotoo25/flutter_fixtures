# Changelog

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
