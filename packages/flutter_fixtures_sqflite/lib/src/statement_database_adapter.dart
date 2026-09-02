import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_adapter.dart';
import 'sqflite_query.dart';

/// A [DatabaseAdapter] whose nine sqflite-shaped operations are translated,
/// once, into a [SqfliteQuery] statement and handed to [run].
///
/// [SqfliteQuery] already carries every field of every operation, so this
/// is the one place the sqflite call surface is turned into a statement;
/// an adapter implements [run] over the statement and nothing else. The
/// built-in adapters — `RealDatabaseAdapter`, `FixtureDatabaseAdapter`,
/// `RecorderDatabaseAdapter` — are each one [run], and a custom adapter
/// (a canned-rows fake, a logging decorator) is the same one method.
///
/// Results come back raw from [run] — rows for reads, a row id or count
/// for writes, anything for `execute` — and are normalized here into the
/// return types repositories expect, including rows that were restored
/// from JSON (see [decodeRows]).
abstract class StatementDatabaseAdapter implements DatabaseAdapter {
  /// Runs one statement and returns its raw result: a list of rows for
  /// `query` / `rawQuery`, an `int` for the write operations, anything
  /// (ignored) for `execute`.
  Future<Object?> run(SqfliteQuery statement);

  /// Normalizes a rows result — including one that went through a JSON
  /// round trip as `List<dynamic>` of `Map<dynamic, dynamic>` — into
  /// sqflite's row shape.
  static List<Map<String, dynamic>> decodeRows(Object? result) {
    return [
      for (final row in (result as List? ?? const []))
        Map<String, dynamic>.from(row as Map),
    ];
  }

  Future<List<Map<String, dynamic>>> _rows(SqfliteQuery statement) async =>
      decodeRows(await run(statement));

  Future<int> _count(SqfliteQuery statement) async =>
      (await run(statement)) as int? ?? 0;

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
    return _rows(SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.query,
      distinct: distinct,
      columns: columns,
      where: where,
      arguments: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    ));
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _rows(SqfliteQuery.raw(sql: sql, arguments: arguments));
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _count(SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.insert,
      values: values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm?.name,
    ));
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _count(SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.update,
      where: where,
      arguments: whereArgs,
      values: values,
      conflictAlgorithm: conflictAlgorithm?.name,
    ));
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _count(SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.delete,
      where: where,
      arguments: whereArgs,
    ));
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _count(SqfliteQuery.raw(
      sql: sql,
      operation: SqfliteOperation.rawInsert,
      arguments: arguments,
    ));
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _count(SqfliteQuery.raw(
      sql: sql,
      operation: SqfliteOperation.rawUpdate,
      arguments: arguments,
    ));
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _count(SqfliteQuery.raw(
      sql: sql,
      operation: SqfliteOperation.rawDelete,
      arguments: arguments,
    ));
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await run(SqfliteQuery.raw(
      sql: sql,
      operation: SqfliteOperation.execute,
      arguments: arguments,
    ));
  }
}
