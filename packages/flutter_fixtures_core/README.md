# Flutter Fixtures Core

[![pub package](https://img.shields.io/pub/v/flutter_fixtures_core.svg)](https://pub.dev/packages/flutter_fixtures_core)

Core interfaces and domain models for the Flutter Fixtures library. This package provides the foundational abstractions that enable extensible fixture-based mocking.

## 🎯 Purpose

This package defines the core contracts and data models used by all Flutter Fixtures implementations. Use this package when:

- Creating custom data providers (database, file system, network, etc.)
- Extending the Flutter Fixtures ecosystem with new data source functionality
- Building libraries that need fixture-based mocking capabilities

## 📦 What's Included

### Interfaces

- **`DataQuery<Input, Output>`**: Abstract interface for querying data sources
- **`DataSelectorView`**: Interface for fixture selection components
- **`FixtureSelector`**: Mixin providing fixture selection functionality

### Data Models

- **`FixtureCollection`**: Container for multiple fixture response options
- **`FixtureDocument`**: Individual fixture response definition

### Selection Strategies

- **`DataSelectorType`**: Sealed class defining fixture selection strategies
  - `Random()`: Randomly select from available fixtures
  - `Default()`: Use the fixture marked as default
  - `Pick()`: Let user choose through UI

### Response Delays

- **`DataSelectorDelay`**: Class for simulating response delays
  - `instant`: No delay (0ms)
  - `fast`: Fast response (~100ms)
  - `moderate`: Moderate response (~500ms)
  - `slow`: Slow response (~2000ms)
  - `custom(milliseconds)`: Custom delay duration

## 🚀 Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_fixtures_core: ^0.1.0
```

## 🛠️ Creating Custom Data Providers

Implement the `DataQuery` interface to create custom data sources:

```dart
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

class DatabaseDataQuery implements DataQuery<String, Map<String, dynamic>> {
  final Database database;

  DatabaseDataQuery(this.database);

  @override
  Future<Map<String, dynamic>?> find(String query) async {
    // Query your database
    final result = await database.query('fixtures', where: 'query = ?', whereArgs: [query]);
    return result.isNotEmpty ? result.first : null;
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    // Parse database result into fixture collection
    return FixtureCollection(
      description: source['description'],
      items: (source['options'] as List).map((item) =>
        FixtureDocument(
          identifier: item['id'],
          description: item['description'],
          defaultOption: item['is_default'] ?? false,
          data: item['response_data'],
        )
      ).toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    // Return the response data
    return document.data;
  }

  @override
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector,
  ) async {
    // Use the FixtureSelector mixin for standard selection logic
    return switch (selector) {
      Pick() => await view?.pick(fixture),
      Default() => fixture.items.firstWhere((item) => item.defaultOption ?? false),
      Random() => fixture.items[Random().nextInt(fixture.items.length)],
    };
  }
}
```



## 🧩 Using the FixtureSelector Mixin

The `FixtureSelector` mixin provides standard fixture selection logic:

```dart
class MyDataProvider with FixtureSelector implements DataQuery<String, Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>?> find(String input) async {
    // Your find implementation
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    // Your parse implementation
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    // Your data implementation
  }

  // select() method is provided by the FixtureSelector mixin
  // It automatically handles delays when specified
}
```

## ⏱️ Simulating Response Delays

Use `DataSelectorDelay` to simulate network latency or other delays:

```dart
// Use predefined delays
await dataQuery.select(
  fixture,
  view,
  DataSelectorType.random(),
  delay: DataSelectorDelay.moderate, // 500ms delay
);

// Or create custom delays
await dataQuery.select(
  fixture,
  view,
  DataSelectorType.random(),
  delay: DataSelectorDelay.custom(1500), // 1.5 second delay
);

// Default is instant (no delay)
await dataQuery.select(
  fixture,
  view,
  DataSelectorType.random(),
  // delay defaults to DataSelectorDelay.instant
);
```

### Available Delays

- **`DataSelectorDelay.instant`** - No delay (0ms) - Default
- **`DataSelectorDelay.fast`** - Fast response (~100ms, comparable to fast 4G/5G)
- **`DataSelectorDelay.moderate`** - Moderate response (~500ms, comparable to 3G)
- **`DataSelectorDelay.slow`** - Slow response (~2000ms, comparable to 2G/EDGE)
- **`DataSelectorDelay.custom(ms)`** - Custom delay with specified milliseconds

## 📋 Data Model Reference

### FixtureCollection

Container for multiple fixture response options:

```dart
final collection = FixtureCollection(
  description: 'User API responses',
  items: [
    FixtureDocument(
      identifier: 'success',
      description: '200 Success',
      defaultOption: true,
      data: {'users': [...]},
    ),
    // ... more fixtures
  ],
);
```

### FixtureDocument

Individual fixture response definition:

```dart
final document = FixtureDocument(
  identifier: 'success',           // Unique identifier
  description: '200 Success',      // Human-readable description
  defaultOption: true,             // Whether this is the default choice
  data: {'users': [...]},          // Inline response data
  dataPath: 'users_large.json',    // Or path to external data file
);
```

### DataSelectorType

Fixture selection strategies:

```dart
// Always use default fixture
final defaultSelector = DataSelectorType.defaultValue();

// Randomly select fixture
final randomSelector = DataSelectorType.random();

// Let user choose via UI (requires DataSelectorView implementation)
final pickSelector = DataSelectorType.pick();
```

### DataSelectorView

Interface for implementing fixture selection mechanisms:

```dart
abstract class DataSelectorView {
  Future<FixtureDocument?> pick(FixtureCollection fixture);
}
```

This interface is implemented by UI packages to provide user-driven fixture selection. The core package defines the contract, while implementation packages (like `flutter_fixtures_ui`) provide concrete implementations.

## 🔗 Integration

This package provides the foundation for:

- **[flutter_fixtures_dio](https://pub.dev/packages/flutter_fixtures_dio)**: Dio HTTP client implementation
- **[flutter_fixtures_ui](https://pub.dev/packages/flutter_fixtures_ui)**: UI components for fixture selection
- **[flutter_fixtures](https://pub.dev/packages/flutter_fixtures)**: Complete library with all components

Use this package directly when building custom data providers or extending the Flutter Fixtures ecosystem.

## 📚 Examples

For complete examples and usage patterns, see the [Flutter Fixtures repository](https://github.com/brotoo25/flutter_fixtures).

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guide](https://github.com/brotoo25/flutter_fixtures/blob/main/CONTRIBUTING.md).

## 📄 License

MIT License - see the [LICENSE](https://github.com/brotoo25/flutter_fixtures/blob/main/LICENSE) file for details.
