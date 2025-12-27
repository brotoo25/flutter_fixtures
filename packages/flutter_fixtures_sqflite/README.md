# Flutter Fixtures SQLite

[![pub package](https://img.shields.io/pub/v/flutter_fixtures_sqflite.svg)](https://pub.dev/packages/flutter_fixtures_sqflite)

SQLite/sqflite implementation for the Flutter Fixtures library. Mock database queries with fixture files for testing and development.

## 🎯 Purpose

This package provides a `DataQuery` implementation for SQLite databases, allowing you to:

- Mock database queries during development and testing
- Test different data scenarios without modifying the database
- Develop UI features before the database schema is finalized
- Create reproducible test scenarios

## 📦 What's Included

### FixtureDatabase

A drop-in replacement for sqflite's `Database` that returns fixture data. Provides the same familiar API (`query`, `insert`, `update`, `delete`) so you can swap between fixture and real databases easily.

### SqfliteDataQuery

A data provider that loads fixture files from your app's assets and returns mock database results.

### SqfliteQuery

A model class representing database queries for fixture matching.

## 🚀 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_fixtures_sqflite: ^0.1.0
  sqflite: ^2.4.1
```

## 📁 Fixture File Structure

Create fixture files in `assets/fixtures/database/` directory:

```
assets/
  fixtures/
    database/
      query_users.json
      query_products.json
      insert_orders.json
```

### Fixture File Format

```json
{
  "description": "User table query fixtures",
  "values": [
    {
      "identifier": "success",
      "description": "Returns list of users",
      "default": true,
      "data": [
        {"id": 1, "name": "John", "email": "john@example.com"},
        {"id": 2, "name": "Jane", "email": "jane@example.com"}
      ]
    },
    {
      "identifier": "empty",
      "description": "Returns empty result",
      "data": []
    },
    {
      "identifier": "single",
      "description": "Returns single user",
      "data": [
        {"id": 1, "name": "John", "email": "john@example.com"}
      ]
    }
  ]
}
```

## 💡 Usage

### Using FixtureDatabase (Recommended)

Use `FixtureDatabase` as a drop-in replacement for sqflite's `Database`:

```dart
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

// Create a fixture database (same API as sqflite's Database)
final db = FixtureDatabase(
  dataQuery: SqfliteDataQuery(),
  dataSelector: DataSelectorType.defaultValue(),
);

// Query just like a real sqflite database!
final users = await db.query('users');
final products = await db.query('products', where: 'category = ?');

// Insert, update, delete also work
final id = await db.insert('users', {'name': 'John', 'email': 'john@example.com'});
await db.update('users', {'name': 'Jane'}, where: 'id = ?');
await db.delete('users', where: 'id = ?');
```

### With Interactive Fixture Selection

```dart
final db = FixtureDatabase(
  dataQuery: SqfliteDataQuery(),
  dataSelector: DataSelectorType.pick(),
  dataSelectorView: FixturesDialogView(context: context),
  delay: DataSelectorDelay.fast,
);

// When querying, a dialog will let you pick which fixture to return
final users = await db.query('users');
```

### Low-Level API

For more control, use `SqfliteDataQuery` directly:

```dart
final dataQuery = SqfliteDataQuery();

// Create a query
final query = SqfliteQuery.table(
  table: 'users',
  operation: SqfliteOperation.query,
);

// Find and parse fixtures
final fixtureData = await dataQuery.find(query);
if (fixtureData != null) {
  final collection = await dataQuery.parse(fixtureData);
  final selected = await dataQuery.select(
    collection!,
    null,
    DataSelectorType.defaultValue(),
  );
  final result = await dataQuery.data(selected!);
  print(result);
}
```

### File Naming Convention

Files should be named based on the query operation and table:

| Query Type | File Name |
|------------|-----------|
| SELECT on users | `query_users.json` |
| INSERT on users | `insert_users.json` |
| UPDATE on users | `update_users.json` |
| DELETE on users | `delete_users.json` |
| SELECT with WHERE | `query_users_id_1.json` |
| Raw SQL query | `rawQuery_{normalized_sql}.json` |

## 🔗 Related Packages

- **[flutter_fixtures](https://pub.dev/packages/flutter_fixtures)**: Complete Flutter Fixtures library
- **[flutter_fixtures_core](https://pub.dev/packages/flutter_fixtures_core)**: Core interfaces and models
- **[flutter_fixtures_dio](https://pub.dev/packages/flutter_fixtures_dio)**: Dio HTTP client implementation
- **[flutter_fixtures_ui](https://pub.dev/packages/flutter_fixtures_ui)**: UI components for fixture selection

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

