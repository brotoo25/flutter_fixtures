# Flutter Fixtures Recorder Dio

The Dio (HTTP) adapter for
[`flutter_fixtures_recorder`](../flutter_fixtures_recorder), the Flutter
Fixtures record & replay module.

## Quick Start

```yaml
dependencies:
  flutter_fixtures_recorder_dio: ^0.1.0
```

```dart
import 'package:flutter_fixtures_recorder_dio/flutter_fixtures_recorder_dio.dart';

final recorder = FixtureRecorder(
  store: FileRecordingSessionStore('${documentsDir.path}/fixture_recordings'),
);

final dio = Dio();
dio.interceptors.add(RecorderInterceptor(recorder: recorder));
```

While the recorder records, every response — including 4xx/5xx responses
surfaced as Dio errors — is captured into the in-progress session. While it
replays, requests are answered from the saved session without touching the
network. Idle, the interceptor is a transparent passthrough.

## Behavior

- Requests are described with source `'http'`, the method as operation, and
  the **path with sorted query** as target. The host is intentionally
  dropped, so a session recorded against staging replays against any
  environment.
- Unrecorded requests during replay **forward to the network** by default;
  pass `onReplayMiss: ReplayMissBehavior.reject` to guarantee the network
  is never touched.
- The captured `content-length` header is not replayed (the re-encoded body
  may differ).
- Add the interceptor **before** other interceptors that produce responses
  (such as `FixturesInterceptor`), so replayed sessions win and recording
  sees the final response.

This package re-exports the recorder core, so a single import covers both.
