import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_adapter.dart';
import 'sqflite_query.dart';

/// A [DatabaseAdapter] that returns fixture data instead of querying a real database.
///
/// Use this class as a drop-in replacement for [RealDatabaseAdapter] during
/// development and testing. It loads mock data from fixture files.
///
/// ## Usage with DatabaseAdapter
///
/// ```dart
/// class UserRepository {
///   final DatabaseAdapter db;
///   UserRepository(this.db);
///
///   Future<List<User>> getUsers() async {
///     final rows = await db.query('users');
///     return rows.map(User.fromMap).toList();
///   }
/// }
///
/// // In production:
/// final db = RealDatabaseAdapter(await openDatabase('app.db'));
///
/// // In development/testing:
/// final db = FixtureDatabaseAdapter(
///   pipeline: FixturePipeline(
///     source: SqfliteFileFixtureSource(),
///     selector: DataSelectorType.pick,
///   ),
/// );
///
/// final repo = UserRepository(db); // Same code, different data source!
/// ```
///
/// ## Fixture Files
///
/// Create fixture files in `assets/fixtures/database/`:
/// - `query_users.json` for `db.query('users')`
/// - `query_products.json` for `db.query('products')`
/// - `insert_orders.json` for `db.insert('orders', ...)`
class FixtureDatabaseAdapter implements DatabaseAdapter {
  /// The pipeline every statement is served through — source, selection
  /// strategy, picker, memory and delay all live there. Build it once,
  /// next to this adapter: remembered choices live in it.
  final FixturePipeline<SqfliteQuery> pipeline;

  bool _isOpen = true;

  FixtureDatabaseAdapter({required this.pipeline});

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

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
  }) async {
    // The statement carries full fidelity; fixture matching stays
    // deliberately lossy through its fixtureCandidates projection.
    final query = SqfliteQuery.table(
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
    );

    return _executeQuery(query);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final query = SqfliteQuery.raw(sql: sql, arguments: arguments);
    return _executeQuery(query);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _executeWrite(
      SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.insert,
        values: values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm?.name,
      ),
      resultKey: 'insertId',
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
    List<Object?>? whereArgs,
  }) {
    return _executeWrite(
      SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.update,
        where: where,
        arguments: whereArgs,
        values: values,
        conflictAlgorithm: conflictAlgorithm?.name,
      ),
      resultKey: 'affectedRows',
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _executeWrite(
      SqfliteQuery.table(
        table: table,
        operation: SqfliteOperation.delete,
        where: where,
        arguments: whereArgs,
      ),
      resultKey: 'affectedRows',
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _executeWrite(
      SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawInsert,
          arguments: arguments),
      resultKey: 'insertId',
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _executeWrite(
      SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawUpdate,
          arguments: arguments),
      resultKey: 'affectedRows',
    );
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _executeWrite(
      SqfliteQuery.raw(
          sql: sql,
          operation: SqfliteOperation.rawDelete,
          arguments: arguments),
      resultKey: 'affectedRows',
    );
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // For DDL statements, just load fixture if available
    await _payloadFor(SqfliteQuery.raw(
        sql: sql, operation: SqfliteOperation.execute, arguments: arguments));
  }

  /// Serves [query] through the pipeline.
  ///
  /// A missing or empty fixture degrades to `null` — callers substitute
  /// their operation's default, so an unfixtured table behaves like an
  /// empty one. A cancelled pick is an explicit user action and is thrown
  /// as [FixtureCancelled].
  Future<Object?> _payloadFor(SqfliteQuery query) async {
    return switch (await pipeline.serve(query)) {
      FixtureServed(:final payload) => payload,
      FixtureCancelled cancelled => throw cancelled,
      FixtureMiss() => null,
    };
  }

  /// Internal method to execute a query and return list of maps
  Future<List<Map<String, dynamic>>> _executeQuery(SqfliteQuery query) async {
    final payload = await _payloadFor(query);

    if (payload is List) {
      return payload.cast<Map<String, dynamic>>();
    }

    if (payload is Map) {
      // Fixture files may wrap rows under a top-level result key.
      final rows = payload['result'];
      if (rows is List) {
        return rows.cast<Map<String, dynamic>>();
      }
      // Single row result
      return [payload.cast<String, dynamic>()];
    }

    return [];
  }

  /// Executes a write-style query; returns the int stored under [resultKey]
  /// in the fixture payload (e.g. `insertId`, `affectedRows`), defaulting
  /// to 1 when the fixture provides none.
  Future<int> _executeWrite(
    SqfliteQuery query, {
    required String resultKey,
  }) async {
    final payload = await _payloadFor(query);
    if (payload is Map && payload[resultKey] is int) {
      return payload[resultKey] as int;
    }
    return 1;
  }
}

/// Backwards-compatible alias for [FixtureDatabaseAdapter].
///
/// @Deprecated('Use FixtureDatabaseAdapter instead')
typedef FixtureDatabase = FixtureDatabaseAdapter;
