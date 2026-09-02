# Flutter Fixtures UI

[![pub package](https://img.shields.io/pub/v/flutter_fixtures_ui.svg)](https://pub.dev/packages/flutter_fixtures_ui)

<div align="center">
  <img src="../../docs/pick.png" alt="Fixtures UI Demo" width="300"/>
  <p><em>Interactive fixture selection with beautiful Material Design</em></p>
</div>

Pre-built UI components for interactive fixture selection in the Flutter Fixtures library. This package provides ready-to-use dialogs and components that let users choose which fixture response to return.

## 🎯 Purpose

This package provides UI components that implement the `DataSelectorView` interface from `flutter_fixtures_core`. Use this package when you want:

- Interactive fixture selection during development
- User-driven testing scenarios
- Demo modes where you can switch between different data states

## 📦 What's Included

### FixturesDialogView
A Material Design dialog that displays fixture options in a clean, selectable list.

## 🚀 Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_fixtures_ui: ^0.3.0
  flutter_fixtures_dio: ^0.3.0
  flutter_fixtures_core: ^0.3.0
```

## 🎨 Dialog Features

The `FixturesDialogView` provides:

- **Clean Material Design**: Follows Flutter's design guidelines
- **Fixture Information**: Shows identifier and description for each option
- **Default Selection**: Automatically selects the default fixture
- **Remember**: Lets the user remember a choice for subsequent requests
- **Cancellation**: Users can cancel without selecting
- **Scrollable**: Handles long lists of fixtures gracefully

<div align="center">
  <img src="../../docs/pick.png" alt="Fixtures Dialog" width="300"/>
  <p><em>Clean Material Design fixture selection dialog</em></p>
</div>

## 🛠️ Usage

`FixturesDialogView` is a plain adapter — construct it with a context
provider so it never holds a stale `BuildContext`:

```dart
// With a navigator key held by your app:
FixturesDialogView(
  contextProvider: () => navigatorKey.currentContext!,
)

// Or bound to a fixed context (fine for short-lived views):
FixturesDialogView.of(context)
```

The dialog uses your app's theme automatically.

## 🔧 Creating Custom UI Components

Implement the `DataSelectorView` interface to create completely custom UI.
A view only presents options and reports the user's answer as a
`FixtureChoice` (or `null` for cancel) — remembering choices, deduplicating
concurrent requests, and applying delays are handled by the core selection
logic, so custom views inherit those behaviors for free:

```dart
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

class BottomSheetSelector implements DataSelectorView {
  final BuildContext Function() contextProvider;

  BottomSheetSelector({required this.contextProvider});

  @override
  Future<FixtureChoice?> pick(FixtureCollection fixture) async {
    return showModalBottomSheet<FixtureChoice>(
      context: contextProvider(),
      isScrollControlled: true,
      builder: (context) => ListView.builder(
        itemCount: fixture.items.length,
        itemBuilder: (context, index) {
          final item = fixture.items[index];
          return Card(
            child: ListTile(
              title: Text(item.identifier),
              subtitle: Text(item.description),
              trailing: item.defaultOption == true
                  ? Icon(Icons.star, color: Colors.amber)
                  : null,
              onTap: () => Navigator.of(context)
                  .pop(FixtureChoice(document: item)),
            ),
          );
        },
      ),
    );
  }
}
```

## 📋 API Reference

### FixturesDialogView

The main dialog adapter for fixture selection.

**Constructors:**
```dart
FixturesDialogView({required BuildContext Function() contextProvider})
FixturesDialogView.of(BuildContext context)
```

**Methods:**
```dart
Future<FixtureChoice?> pick(FixtureCollection fixture)
```

Shows a dialog with the fixture options and returns the user's choice
(the selected document plus the Remember flag), or `null` if cancelled.

## 🔗 Integration

This package works seamlessly with:

- **[flutter_fixtures_core](https://pub.dev/packages/flutter_fixtures_core)**: Provides the base interfaces
- **[flutter_fixtures_dio](https://pub.dev/packages/flutter_fixtures_dio)**: Dio HTTP client integration
- **[flutter_fixtures](https://pub.dev/packages/flutter_fixtures)**: Complete library bundle

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guide](https://github.com/brotoo25/flutter_fixtures/blob/main/CONTRIBUTING.md).

## 📄 License

MIT License - see the [LICENSE](https://github.com/brotoo25/flutter_fixtures/blob/main/LICENSE) file for details.
