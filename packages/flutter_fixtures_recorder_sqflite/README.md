# Flutter Fixtures Recorder Sqflite

The sqflite (database) adapter for
[`flutter_fixtures_recorder`](../flutter_fixtures_recorder), the Flutter
Fixtures record & replay module.

## Quick Start

```yaml
dependencies:
  flutter_fixtures_recorder_sqflite: ^0.1.0
```

`RecordingDatabaseAdapter` decorates any `DatabaseAdapter` from
`flutter_fixtures_sqflite` — the real database or even the fixture-backed
one — so repositories keep the same seam they already use:

```dart
import 'package:flutter_fixtures_recorder_sqflite/flutter_fixtures_recorder_sqflite.dart';

final recorder = FixtureRecorder(
  store: FileRecordingSessionStore('${documentsDir.path}/fixture_recordings'),
);

final db = RecordingDatabaseAdapter(
  inner: RealDatabaseAdapter(await openDatabase('app.db')),
  recorder: recorder,
);
final repo = UserRepository(db); // repositories notice nothing
```

While the recorder records, every operation is delegated to the inner
adapter and its result captured. While it replays, operations are answered
from the saved session without touching the inner adapter — a replayed
`insert` returns the recorded row id without writing anywhere. Idle, the
decorator is a transparent passthrough.

## Behavior

- Operations are described with source `'sqlite'`, the operation name
  (`query`, `insert`, `rawQuery`, ...) as operation, and a canonical JSON
  encoding of the statement and its arguments as target — so the same
  logical statement always matches, and different arguments never do.
- Unrecorded operations during replay **forward to the inner adapter** by
  default; pass `onReplayMiss: ReplayMissBehavior.reject` to fail instead
  and guarantee the database is never touched.
- Reads and mutations are both captured, so replay reproduces row ids and
  affected-row counts exactly as recorded.

Because one `FixtureRecorder` serves every source, the same session can
hold this adapter's database traffic alongside HTTP traffic recorded by
`flutter_fixtures_recorder_dio`.

This package re-exports the recorder core, so a single import covers both.
