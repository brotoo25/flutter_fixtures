import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'statement_database_adapter.dart';
import 'sqflite_query.dart';

/// The sqflite adapter for the record-and-replay seam ([TrafficRecorder]).
///
/// A decorator around any [StatementDatabaseAdapter] (the real database, or
/// even the fixture-backed one): while the recorder is recording, every operation is
/// delegated to the inner adapter and its result captured into the
/// in-progress session; while it is replaying, operations are answered from
/// the active session without touching the inner adapter. When the recorder
/// is idle, the decorator is a transparent passthrough — statements are
/// described and encoded lazily, only when the recorder's mode needs them.
///
/// ```dart
/// final db = RecorderDatabaseAdapter(
///   inner: RealDatabaseAdapter(await openDatabase('app.db')),
///   recorder: recorder,
/// );
/// final repo = UserRepository(db); // repositories notice nothing
/// ```
///
/// Statement identity is [SqfliteQuery]'s knowledge: operations are
/// described with source `'sqlite'`, the [SqfliteOperation] name, and the
/// statement's [SqfliteQuery.recordingTarget] — total and canonical, so
/// the same logical statement always matches and any differing argument
/// never does. Mutations are captured too: replaying an `insert` returns
/// the recorded row id without writing anywhere.
class RecorderDatabaseAdapter extends StatementDatabaseAdapter {
  /// The [RecordedRequest.source] used for database traffic.
  static const String source = RecordedSources.sqlite;

  /// The adapter real traffic is delegated to.
  final StatementDatabaseAdapter inner;

  /// The recorder this adapter feeds and reads. The engine —
  /// `FixtureRecorder` from `flutter_fixtures_recorder` — plugs in here.
  final TrafficRecorder recorder;

  /// Policy for replay operations with no recorded response.
  final ReplayMissBehavior onReplayMiss;

  RecorderDatabaseAdapter({
    required this.inner,
    required this.recorder,
    this.onReplayMiss = ReplayMissBehavior.forward,
  });

  /// One call/return request: the choreography is core's
  /// (`TrafficRecorder.run`); this adapter supplies the description and
  /// the live statement. The JSON target is built only when the recorder's
  /// mode requires it.
  @override
  Future<Object?> run(SqfliteQuery statement) {
    return recorder.run(
      describe: () => RecordedRequest(
        source: source,
        operation: statement.operation.name,
        target: statement.recordingTarget,
        payload: statement.values ?? statement.arguments,
      ),
      live: () => inner.run(statement),
      onMiss: onReplayMiss,
    );
  }

  @override
  Future<void> close() => inner.close();

  @override
  bool get isOpen => inner.isOpen;
}
