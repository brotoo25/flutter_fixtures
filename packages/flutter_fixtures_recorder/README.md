# Flutter Fixtures Recorder

Record real request/response traffic and replay it later, in order — for
product demonstrations, offline environments, and repeatable simulations.

The recorder is a self-contained module: nothing else in Flutter Fixtures
depends on it, and adding it to an app changes nothing until you press
record. It ships with built-in UI tools (a toolbar and a sessions sheet),
but every control they offer is available on the public API, so you can
build your own UI instead.

This package is the **engine**. It knows nothing about HTTP or SQL — one
recorder captures and replays traffic from any data source, and a single
session can hold traffic from several sources at once. The contract
between sources and the engine is the thin `TrafficRecorder` seam in
`flutter_fixtures_core` (just `decide` + `record`); each transport
package ships its own implementation of the capture/replay side:

| Adapter | Ships in | Source |
| --- | --- | --- |
| `RecorderInterceptor` | `flutter_fixtures_dio` | HTTP via a Dio interceptor |
| `RecorderDatabaseAdapter` | `flutter_fixtures_sqflite` | sqflite via a `DatabaseAdapter` decorator |
| (your code) | anywhere | anything else — see [Any source](#any-source) below |

## Quick Start

```yaml
dependencies:
  flutter_fixtures_recorder: ^0.1.0  # the engine + UI tools
  flutter_fixtures_dio: ^0.2.0       # ships RecorderInterceptor
```

Create one recorder, hand it to the adapters for the sources you use, and
drop the toolbar somewhere in your debug/demo UI:

```dart
import 'package:flutter_fixtures_dio/flutter_fixtures_dio.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';

// Files where possible, memory on web — the directory resolves lazily,
// so everything constructs synchronously.
final recorder = FixtureRecorder(
  store: sessionStoreForDirectory(() async =>
      '${(await getApplicationDocumentsDirectory()).path}/fixture_recordings'),
);

// HTTP:
final dio = Dio();
dio.interceptors.add(RecorderInterceptor(recorder: recorder));

// Database (RecorderDatabaseAdapter ships in flutter_fixtures_sqflite):
final db = RecorderDatabaseAdapter(
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
  that progression. Each recording serves **exactly once** — when a key's
  recordings run out, the session's scope has explicitly ended and further
  requests are misses (`restartReplay` rewinds for another pass).
- Misses — requests never recorded, or replayed past their recordings —
  follow the `ReplayMissBehavior` the adapter passes in: **forward** to
  the real source (default) or **reject/fail** to guarantee the real
  source is never touched. The recorder interprets the policy — adapters
  only render the resulting `ReplayDecision`. Composed with
  `FixturesInterceptor` and `forward`, the fixture picker reappears when
  a session runs out — and picks marked "Remember" answer silently.

## The pieces

| Class | Role |
| --- | --- |
| `FixtureRecorder` | The single entry point: mode transitions (idle / recording / replaying), capture, replay lookup, session management. A `ChangeNotifier`, so any widget can observe it. |
| `RecordedRequest` | The source-agnostic description of one request: source + operation + target (+ informational payload). |
| `RecordingSession` / `RecordedInteraction` | The saved artifact: a named, ordered capture of traffic, JSON-serializable. The response inside an interaction is opaque to the recorder — the adapter that wrote it reads it back. |
| `RecordingSessionStore` | The persistence seam: save/load full sessions, list lightweight summaries. Built-ins: `FileRecordingSessionStore` (JSON files, survives restarts) and `MemoryRecordingSessionStore` (runtime-only, web-friendly); `sessionStoreForDirectory` picks the right one per platform. |
| `SessionReplay` | The playback engine: per-request-key cursors over a session. |
| `ReplayDecision` | The recorder's sealed answer per request: `Replayed`, `ForwardToSource`, or `RejectRequest` — returned by `decide`, rendered by adapters. |
| `ReplayMissBehavior` | The miss policy adapters pass to `decide`: forward or reject. |
| `RecorderToolbar` / `stopRecordingWithPrompt` / `showRecordingSessionsSheet` | The built-in UI tools: start/stop recording with a save-or-discard prompt, list/select/delete sessions, stop or restart replay. The prompt and the sheet are plain functions, reusable from a custom control surface. |

## Any source

An adapter is just code that (1) describes its requests as
`RecordedRequest`s, (2) asks `decide` how each one should be handled, and
(3) renders the decision in its own types. That works for an in-memory
cache, a platform channel, a GraphQL client — anything:

```dart
Future<Object?> loadPreferences(FixtureRecorder recorder) async {
  final request = RecordedRequest(
    source: 'memory',
    operation: 'read',
    target: 'user_preferences',
  );

  switch (recorder.decide(() => request)) {
    case Replayed(:final interaction):
      return interaction.response;
    case RejectRequest(:final message):
      throw StateError(message);
    case ForwardToSource():
      final value = await realPreferenceLookup();
      recorder.record(() => RecordedInteraction(
            request: request,
            response: value,
            recordedAt: DateTime.now(),
          )); // the builder runs only while recording
      return value;
  }
}
```

Mode checks, ordered replay, and the miss policy all live behind `decide` —
an adapter never needs to ask the recorder what mode it is in. Both calls
take builder functions the recorder invokes only when its mode needs them,
so idle traffic costs nothing.

Keep the target **normalized** (the same logical request must always
produce the same target) and the response **JSON-encodable** — a
persistent store refuses anything else loudly at save time.

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
        // Or stopRecordingWithPrompt(context, recorder) for the built-in
        // save-or-discard dialog.
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
  Future<List<RecordingSessionSummary>> list() async { ... }
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
      : RecordedRequest.defaultKey(request),
)
```

## Notes

- Responses are stored as JSON. A response that cannot be JSON-encoded
  (a stream, raw bytes) is rejected loudly at save time — a record-time
  error beats a corrupted replay mid-demo.
- `FileRecordingSessionStore` is not available on web;
  `sessionStoreForDirectory` falls back to `MemoryRecordingSessionStore`
  there, so recordings live for the app's lifetime.
- Listing sessions (`recorder.sessions()`) returns lightweight
  `RecordingSessionSummary` values — recorded payloads are not retained by
  a listing, only by a replay.
- Request payloads are informational and never block a save: the Dio
  adapter records anything that is not plain JSON data (multipart
  `FormData`, streams) as its string form.
