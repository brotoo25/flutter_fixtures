# Flutter Fixtures

[![Codemagic build status](https://api.codemagic.io/apps/6965f1db72574e0ba251c21b/ci/status_badge.svg)](https://codemagic.io/app/6965f1db72574e0ba251c21b/ci/latest_build)

A Flutter library for mocking HTTP requests and other data sources with fixture files. This library provides a flexible way to intercept requests and return mock responses, making it ideal for development, testing, and demos.

<div align="center">
  <img src="docs/recording.gif" alt="Flutter Fixtures Demo" width="500"/>
  <p><em>Universal data mocking for Flutter applications</em></p>
</div>

## Packages

This library is designed to be modular and extensible. It consists of the following packages:

- **flutter_fixtures_core**: Core interfaces and domain models
- **flutter_fixtures_dio**: Dio HTTP client implementation
- **flutter_fixtures_sqflite**: SQLite/sqflite database implementation
- **flutter_fixtures_ui**: UI components for fixture selection
- **flutter_fixtures**: Meta-package that combines all the above

## Features

- **Multiple Data Providers**: Support for different data providers (Dio HTTP, sqflite databases, with more planned)
- **Flexible Selection Modes**: Choose how fixtures are selected (random, default, or user-selected)
- **UI Components**: Built-in UI components for user interaction
- **Extensible Architecture**: Easy to extend with new data providers and UI components
- **Modular Design**: Use only the packages you need or the combined meta-package

## Installation

### Complete Package

For the full functionality, add the meta-package to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_fixtures: ^0.1.0
```

Or use the following command:

```bash
flutter pub add flutter_fixtures
```

### Modular Installation

If you only need specific functionality, you can add individual packages:

```yaml
dependencies:
  # Core interfaces and models (required)
  flutter_fixtures_core: ^0.1.0

  # Only if you need Dio support
  flutter_fixtures_dio: ^0.1.0

  # Only if you need sqflite support
  flutter_fixtures_sqflite: ^0.1.0

  # Only if you need UI components
  flutter_fixtures_ui: ^0.1.0
```

### Custom Implementations

You can create your own implementations by depending only on the core package:

```yaml
dependencies:
  flutter_fixtures_core: ^0.1.0
```

Then implement the interfaces provided by the core package to create your custom data providers or UI components.

## Usage

### Basic Usage with Dio

```dart
import 'package:dio/dio.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';

// Create a Dio instance
final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));

// Add the FixturesInterceptor
dio.interceptors.add(
  FixturesInterceptor(
    dataQuery: DioDataQuery(),
    dataSelectorView: FixturesDialogView(
      context: navigatorKey.currentContext!,
    ),
    dataSelector: DataSelectorType.random(),
    dataSelectorDelay: DataSelectorDelay.moderate, // Optional: simulate network delay
  ),
);

// Make requests as usual
final response = await dio.get('/users');
```

### Basic Usage with sqflite

The sqflite integration uses a `DatabaseAdapter` interface that allows you to swap between real databases and fixtures at runtime with **zero code changes** in your repositories.

```dart
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';

// Define your repository using DatabaseAdapter
class UserRepository {
  final DatabaseAdapter db;
  UserRepository(this.db);

  Future<List<Map<String, dynamic>>> getUsers() async {
    return await db.query('users');
  }

  Future<int> createUser(Map<String, dynamic> user) async {
    return await db.insert('users', user);
  }
}

// In development/testing - use fixtures:
final db = FixtureDatabaseAdapter(
  dataQuery: SqfliteDataQuery(),
  dataSelector: DataSelectorType.pick(),
  dataSelectorView: FixturesDialogView(context: context),
);

// In production - use real sqflite:
// final db = RealDatabaseAdapter(await openDatabase('app.db'));

// Same repository code works with both!
final repo = UserRepository(db);
final users = await repo.getUsers();
```

#### sqflite Fixture Files

Create fixture files in `assets/fixtures/database/`:

```json
// assets/fixtures/database/query_users.json
{
  "description": "Users table query",
  "values": [
    {
      "identifier": "Multiple Users",
      "description": "Returns list of users",
      "default": true,
      "data": [
        {"id": 1, "name": "Alice", "email": "alice@example.com"},
        {"id": 2, "name": "Bob", "email": "bob@example.com"}
      ]
    },
    {
      "identifier": "Empty",
      "description": "No users found",
      "data": []
    }
  ]
}
```

The file naming convention is `{operation}_{table}.json`:
- `query_users.json` → `db.query('users')`
- `insert_orders.json` → `db.insert('orders', ...)`
- `update_products.json` → `db.update('products', ...)`
- `delete_sessions.json` → `db.delete('sessions', ...)`

### Fixture Selection Modes

The library supports three fixture selection modes:

1. **Random**: Randomly selects a fixture response
   ```dart
   dataSelector: DataSelectorType.random()
   ```

2. **Default**: Always selects the fixture marked as default
   ```dart
   dataSelector: DataSelectorType.defaultValue()
   ```

3. **Pick**: Shows a dialog for the user to pick the response
   ```dart
   dataSelector: DataSelectorType.pick()
   ```

### Fixture Files

Fixture files should be placed in the `assets/fixtures` directory and included in your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/fixtures/
    - assets/fixtures/data/
```

Example fixture file (`assets/fixtures/GET_users.json`):

```json
{
  "description": "Users List",
  "values": [
    {
      "identifier": "Success",
      "description": "200",
      "default": true,
      "data": {"users": [{"id": 1, "name": "John"}]}
    },
    {
      "identifier": "Empty",
      "description": "200",
      "data": {"users": []}
    },
    {
      "identifier": "Error",
      "description": "500",
      "data": {"error": "Internal Server Error"}
    }
  ]
}
```

## Extensibility

Flutter Fixtures is designed to be highly extensible. You can create your own implementations for different data providers, UI components, or storage mechanisms.

### Response Delays

Simulate network latency to test loading states:

```dart
// Use predefined delays
dataSelectorDelay: DataSelectorDelay.moderate  // 500ms delay

// Or create custom delays
dataSelectorDelay: DataSelectorDelay.custom(1500)  // 1.5 second delay
```

Available options:
- `DataSelectorDelay.instant` - No delay (default)
- `DataSelectorDelay.fast` - ~100ms
- `DataSelectorDelay.moderate` - ~500ms
- `DataSelectorDelay.slow` - ~2000ms
- `DataSelectorDelay.custom(ms)` - Custom delay

### Creating a Custom Data Provider

To create a custom data provider, implement the `DataQuery` interface from the core package:
`DataQuery<Input, Output>` uses one output type for find/parse/data. If your
payload shape varies (for example, map or list), use `Output` as `Object`.

```dart
class MyCustomDataQuery implements DataQuery<MyInput, MyOutput> {
  @override
  Future<MyOutput?> find(MyInput input) async {
    // Your implementation
  }

  @override
  Future<FixtureCollection?> parse(MyOutput source) async {
    // Your implementation
  }

  @override
  Future<MyOutput?> data(FixtureDocument document) async {
    // Your implementation
  }

  @override
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector,
  ) async {
    // You can use the FixtureSelector mixin or implement your own logic
  }
}
```

### Creating a Custom UI Component

To create a custom UI for fixture selection, implement the `DataSelectorView` interface:

```dart
class MyCustomSelectorView implements DataSelectorView {
  @override
  Future<FixtureDocument?> pick(FixtureCollection fixture) async {
    // Your custom UI implementation
  }
}
```

## Future Implementations (To-Do List)

The following implementations are planned for future releases:

### HTTP Clients
- [x] Dio
- [ ] http package
- [ ] Chopper
- [ ] Retrofit
- [ ] GraphQL

### Database Providers
- [x] SQLite (sqflite)
- [ ] Hive
- [ ] Isar
- [ ] ObjectBox
- [ ] Realm

### UI Selectors
- [x] Dialog
- [ ] Bottom Sheet
- [ ] Dropdown
- [ ] Notification with actions
- [ ] Sidebar panel

### Other Features
- [ ] Fixture recording mode
- [ ] Fixture validation
- [x] Response delay simulation
- [ ] Network condition simulation

## Development

### Workspace Structure

This project uses Flutter workspaces to manage multiple packages. The workspace is defined in the root `pubspec.yaml` file:

```yaml
workspace:
  - packages/flutter_fixtures_core
  - packages/flutter_fixtures_dio
  - packages/flutter_fixtures_sqflite
  - packages/flutter_fixtures_ui
  - packages/flutter_fixtures
```

### Melos Commands

This project uses [Melos](https://melos.invertase.dev/) for managing the monorepo. Melos provides powerful scripting and automation capabilities while working alongside Dart's native workspace for dependency resolution.

#### Setup

If you're a contributor or cloning the repository, initialize the workspace:

```bash
# Install dependencies for all packages
dart pub get

# Bootstrap the Melos workspace
melos bootstrap
```

#### Development Workflow

**Run tests:**
```bash
# Run all tests across all packages
melos run test

# Run tests only on packages that changed (faster)
melos run test:changed

# Generate coverage reports
melos run test:coverage
```

**Code quality:**
```bash
# Format all Dart code
melos run format

# Check formatting without making changes (useful for CI)
melos run format:check

# Run static analysis on all packages
melos run analyze

# Analyze only changed packages
melos run analyze:changed

# Run all quality checks (format + analyze + test)
melos run check

# Quick check on changed packages only
melos run check:changed
```

**Package management:**
```bash
# List all managed packages (excludes example app)
melos list

# Run pub get in all packages
melos run get

# Check for outdated dependencies
melos run deps:outdated
```

**Cleaning:**
```bash
# Clean build artifacts and generated files
melos run clean

# Deep clean including pubspec.lock files
melos run clean:deep
```

**Publishing:**
```bash
# Dry run publish to verify packages are ready
melos run publish:check

# Publish packages (interactive)
melos publish
```

**Advanced operations:**
```bash
# Run a command in a specific package
melos exec --scope="flutter_fixtures_core" -- flutter test

# Run a command in packages that depend on core
melos exec --depends-on="flutter_fixtures_core" -- flutter test

# Run a command on all changed packages
melos exec --diff="origin/main" -- flutter analyze
```

#### Why Melos?

- **Automated scripting**: Run commands across all packages with a single command
- **Selective execution**: Execute commands only on changed packages for faster development
- **Version management**: Coordinate versioning and changelog generation across packages
- **Better DX**: Simplified workflows for testing, formatting, and publishing in monorepos

## Example

See the [example](example) directory for a complete example of how to use the library.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

If you'd like to contribute a new implementation from the to-do list, please open an issue first to discuss the approach.

## Support

If you find this library helpful, consider supporting its development:

<a href="https://www.buymeacoffee.com/broto" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
