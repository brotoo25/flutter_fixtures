# Flutter Fixtures Recorder

Recording and playback for Flutter Fixtures user selections.

## Features

- **Record** user fixture selections during app usage
- **Save** sessions with custom names to filesystem (JSON format)
- **Replay** sessions by auto-selecting recorded choices
- **Manage** sessions with a simple UI (list, play, delete)
- **Overlay UI** with floating action button for easy access
- **Extensible** design for custom data sources and storage backends

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_fixtures_recorder: ^0.1.0
```

### Basic Setup

1. Create a recorder instance:

```dart
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';

final recorder = FixtureRecorder(
  storage: JsonFileSessionStorage(),
);
```

2. Wrap your data queries:

```dart
// For Dio HTTP
final dioDataQuery = RecordableDataQuery(
  delegate: DioDataQuery(),
  recorder: recorder,
  source: 'dio',
);

dio.interceptors.add(
  FixturesInterceptor(
    dataQuery: dioDataQuery,
    dataSelectorView: FixturesDialogView(context: context),
    dataSelector: DataSelectorType.pick(),
  ),
);

// For SQLite
final sqfliteDataQuery = RecordableDataQuery(
  delegate: SqfliteDataQuery(),
  recorder: recorder,
  source: 'sqflite',
);

final db = FixtureDatabaseAdapter(
  dataQuery: sqfliteDataQuery,
  dataSelector: DataSelectorType.pick(),
  dataSelectorView: FixturesDialogView(context: context),
);
```

3. Add the overlay widget to your app:

```dart
Stack(
  children: [
    MaterialApp(...),
    RecorderOverlayWidget(
      recorder: recorder,
      isMockMode: true, // Set based on your app's mock mode
    ),
  ],
);
```

### Using the Integration Mixin

For cleaner setup, use the `RecorderIntegrationMixin`:

```dart
class MyApp extends StatelessWidget with RecorderIntegrationMixin {
  @override
  Widget build(BuildContext context) {
    final recorder = getOrCreateRecorder();

    final dio = Dio();
    dio.interceptors.add(
      FixturesInterceptor(
        dataQuery: wrapDataQuery(DioDataQuery(), 'dio'),
        dataSelectorView: FixturesDialogView(context: context),
        dataSelector: DataSelectorType.pick(),
      ),
    );

    return Stack(
      children: [
        MaterialApp(...),
        RecorderOverlayWidget(recorder: recorder, isMockMode: true),
      ],
    );
  }
}
```

## Usage

### Recording a Session

1. Tap the blue FAB button in the bottom-right corner
2. Select "Start Recording"
3. Interact with your app and select fixtures as needed
4. Tap the red FAB button (now showing "STOP")
5. Enter a name for the session
6. Tap "Save"

**Note:** Default selections and consecutive repeats are automatically filtered out.

### Playing Back a Session

1. Tap the blue FAB button
2. Select a session from the list
3. Interact with your app - fixtures will be auto-selected based on the recording
4. Tap the green FAB button to stop playback

### Managing Sessions

- **View sessions:** Tap the FAB button to see all saved sessions
- **Delete session:** Tap the red trash icon on a session
- **Session info:** Each session shows the number of events and last used time

## Architecture

### Core Components

- **FixtureRecorder**: Main service managing recording/playback state
- **RecordableDataQuery**: Wrapper that adds recording to any DataQuery
- **JsonFileSessionStorage**: Stores sessions as JSON files
- **RecorderOverlayWidget**: Floating button UI

### Recording Flow

```
User selects fixture
    ↓
RecordableDataQuery intercepts
    ↓
Recorder filters (skip defaults & repeats)
    ↓
Event added to buffer
    ↓
User saves → JSON file written
```

### Playback Flow

```
User starts playback
    ↓
Session loaded → playback map built
    ↓
Fixture requested
    ↓
RecordableDataQuery checks playback map
    ↓
Recorded selection returned (or fallback)
```

## Filtering Logic

The recorder automatically filters out:

1. **Default selections**: Fixtures with `defaultOption: true`
2. **Consecutive repeats**: Same fixture + same identifier selected twice in a row

This keeps recordings clean and focused on intentional user choices.

## Extensibility

### Custom Storage Backend

Implement the `SessionStorage` interface:

```dart
class MyCustomStorage implements SessionStorage {
  @override
  Future<void> saveSession(RecordingSession session) async {
    // Custom save logic
  }

  @override
  Future<RecordingSession?> loadSession(String name) async {
    // Custom load logic
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    // Custom list logic
  }

  @override
  Future<void> deleteSession(String name) async {
    // Custom delete logic
  }
}

final recorder = FixtureRecorder(storage: MyCustomStorage());
```

### Custom Data Sources

Wrap any `DataQuery` implementation:

```dart
final customDataQuery = RecordableDataQuery(
  delegate: MyCustomDataQuery(),
  recorder: recorder,
  source: 'my_source',
);
```

### Programmatic Access

Access sessions programmatically for custom workflows:

```dart
// List all sessions
final sessions = await recorder.listSessions();

// Load a specific session
final storage = JsonFileSessionStorage();
final session = await storage.loadSession('my_session');

// Process events
for (final event in session!.events) {
  print('${event.fixtureKey} → ${event.selectedIdentifier}');
}
```

## File Storage

Sessions are stored as JSON files in:
```
<app_documents>/flutter_fixtures_sessions/session_<name>.json
```

Example session file:
```json
{
  "name": "login_flow_happy_path",
  "createdAt": "2026-01-13T10:30:00.000Z",
  "lastUsedAt": "2026-01-13T15:45:00.000Z",
  "events": [
    {
      "fixtureKey": "GET /users/profile",
      "selectedIdentifier": "success_with_premium",
      "timestamp": "2026-01-13T10:30:15.123Z",
      "source": "dio"
    }
  ]
}
```

## License

MIT License - see [LICENSE](../../LICENSE) file for details.
