# Flutter Fixtures Recorder

Record real request/response traffic and replay it later, in order — for
product demonstrations, offline environments, and repeatable simulations.

The recorder is a self-contained module: nothing else in Flutter Fixtures
depends on it, and adding it to an app changes nothing until you press
record. It ships with built-in UI tools (a toolbar and a sessions sheet),
but every control they offer is available on the public API, so you can
build your own UI instead.

This package is the **source-agnostic core**. It knows nothing about HTTP
or SQL — one recorder captures and replays traffic from any data source,
and a single session can hold traffic from several sources at once.
Adapters plug the sources in:

| Package | Source |
| --- | --- |
| `flutter_fixtures_recorder_dio` | HTTP via a Dio interceptor |
| `flutter_fixtures_recorder_sqflite` | sqflite via a `DatabaseAdapter` decorator |
| (your code) | anything else — see [Any source](#any-source) below |

## Quick Start

```yaml
dependencies:
  flutter_fixtures_recorder_dio: ^0.1.0      # HTTP recording
  flutter_fixtures_recorder_sqflite: ^0.1.0  # database recording (optional)
```

Create one recorder, hand it to the adapters for the sources you use, and
drop the toolbar somewhere in your debug/demo UI:

```dart
import 'package:flutter_fixtures_recorder_dio/flutter_fixtures_recorder_dio.dart';

final recorder = FixtureRecorder(
  store: FileRecordingSessionStore('${documentsDir.path}/fixture_recordings'),
);

// HTTP:
final dio = Dio();
dio.interceptors.add(RecorderInterceptor(recorder: recorder));

// Database (flutter_fixtures_recorder_sqflite):
final db = RecordingDatabaseAdapter(
  inner: RealDatabaseAdapter(await openDatabase('app.db')),
  recorder: recorder,
);

// Anywhere in your widget tree:
RecorderToolbar(recorder: recorder)
```

Press record, exercise the app, stop and name the session. Later — with or
without internet — pick the session from the sessions sheet and every wired
source receives the same responses in the same order.

## How replay works

- Every source describes a request in the same shape (`RecordedRequest`):
  a **source** name (`'http'`, `'sqlite'`, ...), an **operation** (an HTTP
  method, `query`, `insert`, ...), and a normalized **target** (a path with
  sorted query, a SQL statement with its arguments). The default match key
  is `source operation target`, so sources never collide inside a session.
- Repeated requests with the same key are served **in recorded order**: a
  polling endpoint captured as `pending → pending → done` replays exactly
  that progression. After the recordings run out, the last response
  repeats, which keeps long demos alive.
- Requests with no recording follow the adapter's `ReplayMissBehavior`:
  **forward** to the real source (default) or **reject/fail** to guarantee
  the real source is never touched.

## The pieces

| Class | Role |
| --- | --- |
| `FixtureRecorder` | The single entry point: mode transitions (idle / recording / replaying), capture, replay lookup, session management. A `ChangeNotifier`, so any widget can observe it. |
| `RecordedRequest` | The source-agnostic description of one request: source + operation + target (+ informational payload). |
| `RecordingSession` / `RecordedInteraction` | The saved artifact: a named, ordered capture of traffic, JSON-serializable. The response inside an interaction is opaque to the recorder — the adapter that wrote it reads it back. |
| `RecordingSessionStore` | The persistence seam. Built-ins: `FileRecordingSessionStore` (JSON files, survives restarts) and `MemoryRecordingSessionStore` (runtime-only, web-friendly). |
| `SessionReplay` | The playback engine: per-request-key cursors over a session. |
| `ReplayMissBehavior` | The adapters' policy for unrecorded requests during replay. |
| `RecorderToolbar` / `showRecordingSessionsSheet` | The built-in UI tools: start/stop recording with a save prompt, list/select/delete sessions, stop or restart replay. |

## Any source

An adapter is just code that (1) describes its requests as
`RecordedRequest`s, (2) offers recorded responses back before doing real
work, and (3) captures real results while recording. That works for an
in-memory cache, a platform channel, a GraphQL client — anything:

```dart
Future<Object?> loadPreferences(FixtureRecorder recorder) async {
  final request = RecordedRequest(
    source: 'memory',
    operation: 'read',
    target: 'user_preferences',
  );

  final replayed = recorder.replayResponseFor(request);
  if (replayed != null) return replayed.response;

  final value = await realPreferenceLookup();
  recorder.record(RecordedInteraction(
    request: request,
    response: value,
    recordedAt: DateTime.now(),
  )); // no-op unless recording
  return value;
}
```

Keep the target **normalized** (the same logical request must always
produce the same target) and the response **JSON-encodable** if sessions
should survive file storage.

## Bring your own UI

The built-in widgets are plain listeners on `FixtureRecorder` — they use no
private hooks. A custom control surface is just:

```dart
ListenableBuilder(
  listenable: recorder,
  builder: (context, _) => switch (recorder.mode) {
    RecorderMode.idle => IconButton(
        icon: const Icon(Icons.fiber_manual_record),
        onPressed: recorder.startRecording,
      ),
    RecorderMode.recording => IconButton(
        icon: const Icon(Icons.stop),
        onPressed: () => recorder.stopRecording(name: 'My demo'),
      ),
    RecorderMode.replaying => IconButton(
        icon: const Icon(Icons.stop),
        onPressed: recorder.stopReplay,
      ),
  },
)
```

Sessions are listed with `recorder.sessions()`, replayed with
`recorder.startReplay(id)` (or `startReplayOf(session)` for sessions built
in code or bundled with the app), and deleted with
`recorder.deleteSession(id)`.

## Custom storage

Implement `RecordingSessionStore` to keep sessions anywhere — a database, a
remote service, shared preferences:

```dart
class MyStore implements RecordingSessionStore {
  Future<void> save(RecordingSession session) async { ... }
  Future<RecordingSession?> load(String id) async { ... }
  Future<List<RecordingSession>> list() async { ... }
  Future<void> delete(String id) async { ... }
}
```

## Custom request matching

If your requests carry volatile parts (timestamps, signatures in an HTTP
query), provide a custom key builder so they still match during replay:

```dart
FixtureRecorder(
  store: store,
  keyOf: (request) => request.source == 'http'
      ? '${request.source} ${request.operation} ${request.target.split('?').first}'
      : request.requestKey,
)
```

## Notes

- Responses are stored as JSON; values that cannot be JSON-encoded
  (streams, raw bytes) are stored as their string representation.
- `FileRecordingSessionStore` is not available on web — use
  `MemoryRecordingSessionStore` or a custom store there.
