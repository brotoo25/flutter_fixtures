import 'dart:convert';

import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// The sqflite adapter for the recorder module.
///
/// A decorator around any [DatabaseAdapter] (the real database, or even the
/// fixture-backed one): while the recorder is recording, every operation is
/// delegated to the inner adapter and its result captured into the
/// in-progress session; while it is replaying, operations are answered from
/// the active session without touching the inner adapter. When the recorder
/// is idle, the decorator is a transparent passthrough.
///
/// ```dart
/// final db = RecordingDatabaseAdapter(
///   inner: RealDatabaseAdapter(await openDatabase('app.db')),
///   recorder: recorder,
/// );
/// final repo = UserRepository(db); // repositories notice nothing
/// ```
///
/// Database operations are described to the recorder with source
/// `'sqlite'`, the operation name (`query`, `insert`, `rawQuery`, ...) as
/// operation, and a canonical JSON encoding of the statement and its
/// arguments as target. Mutations are captured too: replaying an `insert`
/// returns the recorded row id without writing anywhere.
class RecordingDatabaseAdapter implements DatabaseAdapter {
  /// The [RecordedRequest.source] used for database traffic.
  static const String source = 'sqlite';

  /// The adapter real traffic is delegated to.
  final DatabaseAdapter inner;

  /// The recorder this adapter feeds and reads.
  final FixtureRecorder recorder;

  /// Policy for replay operations with no recorded response.
  final ReplayMissBehavior onReplayMiss;

  RecordingDatabaseAdapter({
    required this.inner,
    required this.recorder,
    this.onReplayMiss = ReplayMissBehavior.forward,
  });

  /// Renders the recorder's decision for one operation: serve the recorded
  /// response, fail, or run the real operation and capture its result while
  /// recording.
  Future<T> _run<T>(
    RecordedRequest request,
    Future<T> Function() live,
    T Function(Object? recorded) decode,
  ) async {
    switch (recorder.decide(request, onMiss: onReplayMiss)) {
      case Replayed(:final interaction):
        return decode(interaction.response);
      case RejectRequest(:final message):
        throw StateError(message);
      case ForwardToSource():
        final result = await live();
        recorder.record(RecordedInteraction(
          request: request,
          response: result,
          recordedAt: DateTime.now(),
        ));
        return result;
    }
  }

  /// Canonical target: JSON with a fixed field order, nulls omitted, so the
  /// same logical statement always produces the same target.
  static String _target(Map<String, Object?> fields) {
    fields.removeWhere((_, value) => value == null);
    return jsonEncode(fields);
  }

  static RecordedRequest _request(
    String operation,
    Map<String, Object?> fields, {
    Object? payload,
  }) {
    return RecordedRequest(
      source: source,
      operation: operation,
      target: _target(fields),
      payload: payload,
    );
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
      _request('query', {
        'table': table,
        'distinct': distinct,
        'columns': columns,
        'where': where,
        'whereArgs': whereArgs,
        'groupBy': groupBy,
        'having': having,
        'orderBy': orderBy,
        'limit': limit,
        'offset': offset,
      }),
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
      _request('rawQuery', {'sql': sql, 'arguments': arguments}),
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
      _request(
        'insert',
        {
          'table': table,
          'values': values,
          'nullColumnHack': nullColumnHack,
          'conflictAlgorithm': conflictAlgorithm?.name,
        },
        payload: values,
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
      _request(
        'update',
        {
          'table': table,
          'values': values,
          'where': where,
          'whereArgs': whereArgs,
          'conflictAlgorithm': conflictAlgorithm?.name,
        },
        payload: values,
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
      _request('delete', {
        'table': table,
        'where': where,
        'whereArgs': whereArgs,
      }),
      () => inner.delete(table, where: where, whereArgs: whereArgs),
      _decodeInt,
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _run(
      _request('rawInsert', {'sql': sql, 'arguments': arguments}),
      () => inner.rawInsert(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _run(
      _request('rawUpdate', {'sql': sql, 'arguments': arguments}),
      () => inner.rawUpdate(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _run(
      _request('rawDelete', {'sql': sql, 'arguments': arguments}),
      () => inner.rawDelete(sql, arguments),
      _decodeInt,
    );
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _run<Object?>(
      _request('execute', {'sql': sql, 'arguments': arguments}),
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
