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

- **`DataSelectorView`**: Interface for fixture selection components
- **`FixturePipeline`**: The module owning the whole serve flow — source lookup, strategy dispatch, remembered choices, pick deduplication, delays — behind one `serve` call, delays — and the `serve` pipeline (find → select → data), reported as a `FixtureOutcome`

### Data Models

- **`FixtureCollection`**: Container for multiple fixture response options
- **`FixtureDocument`**: Individual fixture response definition

### Fixture Sources

- **`FixtureSource`**: Fixture-file IO — candidate resolution, JSON decoding, payload loading
- **`HttpFixtureSource`**: Seam for providing HTTP fixtures; adapters consult an ordered list of sources per `HttpFixtureRequest`
- **`FixtureSource<TRequest>`** / **`FixtureFileSource`**: The fixture-source seam for any request type, and the one file-backed adapter every domain reuses through its naming convention
- **`HttpFileFixtureSource`**: The file-backed source — maps a request to fixture-file candidates and delegates to `FixtureSource`
- **`OpenApiFixtureSource`**: The OpenAPI-backed source — a 3.x JSON document's response documentation and payload examples become fixtures
- **`FixtureAssetLoader`**: Seam for reading fixture assets (`BundleAssetLoader` in production)

### Selection Strategies

- **`DataSelectorType`**: Enum defining fixture selection strategies
  - `random`: Randomly select from available fixtures
  - `defaultValue`: Use the fixture marked as default
  - `pick`: Let user choose through UI

### Response Delays

- **`DataSelectorDelay`**: Named `Duration` presets for simulating response delays
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

## 🛠️ Creating Custom Fixture Providers

A fixture provider is a **source**: something that turns a domain request
into a `FixtureCollection` and materializes a document's payload. Every
domain shares one seam, `FixtureSource<TRequest>`, typed by its request
model (`HttpFixtureSource` and `SqfliteFixtureSource` are aliases). For
fixture files, the built-in `FixtureFileSource` does all the IO — a domain
contributes only its naming convention:

```dart
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// A file-backed source for a cache domain: the request is a cache key.
class CacheFixtureSource extends FixtureFileSource<String> {
  CacheFixtureSource({String mockFolder = 'assets/fixtures/cache'})
      : super(mockFolder: mockFolder, candidates: (key) => ['$key.json']);
}

/// The consumer holds one pipeline and renders outcomes for its domain.
class FixtureCache {
  FixtureCache({required this.pipeline});

  final FixturePipeline<String> pipeline;

  Future<Object?> read(String cacheKey) async {
    return switch (await pipeline.serve(cacheKey)) {
      FixtureServed(:final payload) => payload,
      FixtureCancelled cancelled => throw cancelled,
      FixtureMiss() => null, // your domain's default
    };
  }
}

final cache = FixtureCache(
  pipeline: FixturePipeline(
    source: CacheFixtureSource(),
    selector: DataSelectorType.pick,
    view: myView,
  ),
);
```

`FixturePipeline.serve` owns the find → select → load choreography and
returns a `FixtureOutcome`: `FixtureServed` (the selected document plus its
payload) or a `FixtureMiss` — `FixtureNotFound`, `FixtureEmpty`,
`FixtureCancelled` — which is also an `Exception`, so adapters throw the
outcome itself. Remembered choices, pick deduplication, and delays live in
the pipeline; build it once for the lifetime you want choices remembered.

## ⏱️ Simulating Response Delays

Delays are plain `Duration`s; `DataSelectorDelay` names four presets:

```dart
// Use predefined delays
await selector.select(
  fixture,
  view,
  DataSelectorType.random,
  delay: DataSelectorDelay.moderate, // 500ms delay
);

// Or create custom delays
await selector.select(
  fixture,
  view,
  DataSelectorType.random,
  delay: const Duration(milliseconds: 1500), // 1.5 second delay
);

// Default is instant (no delay)
await selector.select(
  fixture,
  view,
  DataSelectorType.random,
  // delay defaults to DataSelectorDelay.instant
);
```

### Available Delays

- **`DataSelectorDelay.instant`** - No delay (0ms) - Default
- **`DataSelectorDelay.fast`** - Fast response (~100ms, comparable to fast 4G/5G)
- **`DataSelectorDelay.moderate`** - Moderate response (~500ms, comparable to 3G)
- **`DataSelectorDelay.slow`** - Slow response (~2000ms, comparable to 2G/EDGE)
- **any `Duration`** - Custom delay, e.g. `Duration(milliseconds: 1500)`

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
final defaultSelector = DataSelectorType.defaultValue;

// Randomly select fixture
final randomSelector = DataSelectorType.random;

// Let user choose via UI (requires DataSelectorView implementation)
final pickSelector = DataSelectorType.pick;
```

### DataSelectorView

Interface for implementing fixture selection mechanisms:

```dart
abstract class DataSelectorView {
  /// Returns the user's choice, or null if cancelled.
  Future<FixtureChoice?> pick(FixtureCollection fixture);
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
