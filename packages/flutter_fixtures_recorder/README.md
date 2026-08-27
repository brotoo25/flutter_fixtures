# Flutter Fixtures Recorder

Record real request/response traffic and replay it later, in order — for
product demonstrations, offline environments, and repeatable simulations.

The recorder is a self-contained module: nothing else in Flutter Fixtures
depends on it, and adding it to an app changes nothing until you press
record. It ships with built-in UI tools (a toolbar and a sessions sheet),
but every control they offer is available on the public API, so you can
build your own UI instead.

## Quick Start

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_fixtures_recorder: ^0.1.0
```

Wire the recorder into your Dio client and drop the toolbar somewhere in
your debug/demo UI:

```dart
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';

final recorder = FixtureRecorder(
  store: FileRecordingSessionStore('${documentsDir.path}/fixture_recordings'),
);

final dio = Dio();
dio.interceptors.add(RecorderInterceptor(recorder: recorder));

// Anywhere in your widget tree:
RecorderToolbar(recorder: recorder)
```

Press record, exercise the app, stop and name the session. Later — with or
without internet — pick the session from the sessions sheet and the app
receives the same responses in the same order.

## How replay works

- Requests are matched by **method + path + sorted query** (the host is
  ignored, so a session recorded against staging replays anywhere).
- Repeated calls to the same endpoint are served **in recorded order**: a
  polling endpoint captured as `pending → pending → done` replays exactly
  that progression. After the recordings run out, the last response repeats,
  which keeps long demos alive.
- Requests with no recording **forward to the network** by default; pass
  `onReplayMiss: ReplayMissBehavior.reject` to guarantee the network is
  never touched.
- Error-status responses (4xx/5xx) are recorded and replayed too.

## The pieces

| Class | Role |
| --- | --- |
| `FixtureRecorder` | The single entry point: mode transitions (idle / recording / replaying), capture, replay lookup, session management. A `ChangeNotifier`, so any widget can observe it. |
| `RecorderInterceptor` | The Dio adapter. Captures responses while recording, answers requests while replaying, passes traffic through while idle. |
| `RecordingSession` / `RecordedInteraction` | The saved artifact: a named, ordered capture of traffic, JSON-serializable. |
| `RecordingSessionStore` | The persistence seam. Built-ins: `FileRecordingSessionStore` (JSON files, survives restarts) and `MemoryRecordingSessionStore` (runtime-only, web-friendly). |
| `SessionReplay` | The playback engine: per-request-key cursors over a session. |
| `RecorderToolbar` / `showRecordingSessionsSheet` | The built-in UI tools: start/stop recording with a save prompt, list/select/delete sessions, stop or restart replay. |

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

If your requests carry volatile query parameters (timestamps, signatures),
provide a custom key builder so they match during replay:

```dart
FixtureRecorder(
  store: store,
  keyOf: (method, uri) => '$method ${uri.path}', // ignore all query params
)
```

## Notes

- Response payloads are stored as JSON; payloads that cannot be
  JSON-encoded (streams, raw bytes) are stored as their string
  representation.
- `FileRecordingSessionStore` is not available on web — use
  `MemoryRecordingSessionStore` or a custom store there.
- Add `RecorderInterceptor` **before** interceptors that produce responses
  (such as `FixturesInterceptor`), so replay wins and recording sees the
  final response.
