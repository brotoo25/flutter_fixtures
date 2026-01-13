import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_adapter.dart';

/// A [DatabaseAdapter] that wraps a real sqflite [Database].
///
/// Use this in production to interact with an actual SQLite database.
///
/// ## Usage
///
/// ```dart
/// final database = await openDatabase('app.db');
/// final adapter = RealDatabaseAdapter(database);
///
/// // Use the adapter in your repositories
/// final users = await adapter.query('users');
/// ```
class RealDatabaseAdapter implements DatabaseAdapter {
  /// The underlying sqflite database.
  final sqflite.Database _database;

  /// Creates an adapter wrapping a real sqflite database.
  RealDatabaseAdapter(this._database);

  /// Access the underlying sqflite Database for advanced operations.
  ///
  /// Use this for features not covered by [DatabaseAdapter], such as
  /// transactions and batch operations.
  sqflite.Database get database => _database;

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
    return _database.query(
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
    );
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _database.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _database.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
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
    return _database.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _database.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _database.rawInsert(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _database.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _database.rawDelete(sql, arguments);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _database.execute(sql, arguments);
  }

  @override
  Future<void> close() {
    return _database.close();
  }

  @override
  bool get isOpen => _database.isOpen;
}
