# Changelog

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
