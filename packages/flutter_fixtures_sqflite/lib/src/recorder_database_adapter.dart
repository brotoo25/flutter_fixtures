import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_adapter.dart';
import 'sqflite_query.dart';

/// The sqflite adapter for the record-and-replay seam ([TrafficRecorder]).
///
/// A decorator around any [DatabaseAdapter] (the real database, or even the
/// fixture-backed one): while the recorder is recording, every operation is
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
class RecorderDatabaseAdapter implements DatabaseAdapter {
  /// The [RecordedRequest.source] used for database traffic.
  static const String source = 'sqlite';

  /// The adapter real traffic is delegated to.
  final DatabaseAdapter inner;

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

  /// Renders the recorder's decision for one operation: serve the recorded
  /// response, fail, or run the real operation and capture its result while
  /// recording. The statement (and its JSON target) is built only when the
  /// recorder's mode requires it.
  Future<T> _run<T>(
    SqfliteQuery Function() statement,
    Future<T> Function() live,
    T Function(Object? recorded) decode,
  ) async {
    RecordedRequest describe() {
      final resolved = statement();
      return RecordedRequest(
        source: source,
        operation: resolved.operation.name,
        target: resolved.recordingTarget,
        payload: resolved.values ?? resolved.arguments,
      );
    }

    switch (recorder.decide(describe, onMiss: onReplayMiss)) {
      case Replayed(:final interaction):
        return decode(interaction.response);
      case RejectRequest(:final message):
        throw StateError(message);
      case ForwardToSource():
        final result = await live();
        recorder.record(() => RecordedInteraction(
              request: describe(),
              response: result,
              recordedAt: DateTime.now(),
            ));
        return result;
    }
  }

  /// Recorded rows survive a JSON round-trip as `List<dynamic>` of
  /// `Map<dynamic, dynamic>`; normalize back to sqflite's row shape.
  static List<Map<String, dynamic>> _decodeRows(Object? recorded) {
    return [
      for (final row in (recorded as List? ?? const []))
        Map<String, dynamic>.from(row as Map),
    ];
  }

  static int _decodeInt(Object? recorded) => recorded as int? ?? 0;

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _run(
      () => SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.query,
        where: where,
        columns: columns,
        arguments: whereArgs,
        distinct: distinct,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
      () => inner.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
      _decodeRows,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _run(
      () => SqfliteQuery.raw(sql: sql, arguments: arguments),
      () => inner.rawQuery(sql, arguments),
      _decodeRows,
    );
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _run(
      () => SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.insert,
        values: values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm?.name,
      ),
      () => inner.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
      _decodeInt,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _run(
      () => SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.update,
        where: where,
        arguments: whereArgs,
        values: values,
        conflictAlgorithm: conflictAlgorithm?.name,
      ),
      () => inner.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
      _decodeInt,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _run(
      () => SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.delete,
        where: where,
        arguments: whereArgs,
      ),
      () => inner.delete(table, where: where, whereArgs: whereArgs),
      _decodeInt,
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _run(
      () => SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawInsert,
          arguments: arguments),
      () => inner.rawInsert(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _run(
      () => SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawUpdate,
          arguments: arguments),
      () => inner.rawUpdate(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _run(
      () => SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawDelete,
          arguments: arguments),
      () => inner.rawDelete(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _run<Object?>(
      () => SqfliteQuery.raw(
          sql: sql, operation: SqfliteOperation.execute, arguments: arguments),
      () async {
        await inner.execute(sql, arguments);
        return null;
      },
      (_) => null,
    );
  }

  @override
  Future<void> close() => inner.close();

  @override
  bool get isOpen => inner.isOpen;
}
