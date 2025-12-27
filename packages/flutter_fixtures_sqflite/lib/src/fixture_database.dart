import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_adapter.dart';
import 'sqflite_data_query.dart';
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
///   dataQuery: SqfliteDataQuery(),
///   dataSelector: DataSelectorType.pick(),
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
  /// The data query implementation for loading fixtures
  final SqfliteDataQuery dataQuery;

  /// The selector type for choosing which fixture to return
  final DataSelectorType dataSelector;

  /// Optional view for user-driven fixture selection
  final DataSelectorView? dataSelectorView;

  /// Optional delay to simulate database latency
  final DataSelectorDelay delay;

  bool _isOpen = true;

  /// Creates a new FixtureDatabaseAdapter
  FixtureDatabaseAdapter({
    required this.dataQuery,
    required this.dataSelector,
    this.dataSelectorView,
    this.delay = DataSelectorDelay.instant,
  });

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
    final query = SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.query,
      where: where,
      columns: columns,
    );

    return _executeQuery(query);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final query = SqfliteQuery.raw(sql: sql);
    return _executeQuery(query);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final query = SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.insert,
    );

    final result = await _executeQueryRaw(query);
    // Return mock ID from fixture or default to 1
    if (result is Map && result.containsKey('insertId')) {
      return result['insertId'] as int;
    }
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
    List<Object?>? whereArgs,
  }) async {
    final query = SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.update,
      where: where,
    );

    final result = await _executeQueryRaw(query);
    // Return affected count from fixture or default to 1
    if (result is Map && result.containsKey('affectedRows')) {
      return result['affectedRows'] as int;
    }
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final query = SqfliteQuery.table(
      table: table,
      operation: SqfliteOperation.delete,
      where: where,
    );

    final result = await _executeQueryRaw(query);
    // Return affected count from fixture or default to 1
    if (result is Map && result.containsKey('affectedRows')) {
      return result['affectedRows'] as int;
    }
    return 1;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final query = SqfliteQuery.raw(sql: sql);
    final result = await _executeQueryRaw(query);
    if (result is Map && result.containsKey('insertId')) {
      return result['insertId'] as int;
    }
    return 1;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final query = SqfliteQuery.raw(sql: sql);
    final result = await _executeQueryRaw(query);
    if (result is Map && result.containsKey('affectedRows')) {
      return result['affectedRows'] as int;
    }
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final query = SqfliteQuery.raw(sql: sql);
    final result = await _executeQueryRaw(query);
    if (result is Map && result.containsKey('affectedRows')) {
      return result['affectedRows'] as int;
    }
    return 1;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // For DDL statements, just load fixture if available
    await _executeQueryRaw(SqfliteQuery.raw(sql: sql));
  }

  /// Internal method to execute a query and return list of maps
  Future<List<Map<String, dynamic>>> _executeQuery(SqfliteQuery query) async {
    final result = await _executeQueryRaw(query);

    if (result == null) {
      return [];
    }

    // Handle the result format
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }

    if (result is Map) {
      // Check if it's wrapped in a 'result' key
      if (result.containsKey('result') && result['result'] is List) {
        return (result['result'] as List).cast<Map<String, dynamic>>();
      }
      // Single row result
      return [result.cast<String, dynamic>()];
    }

    return [];
  }

  /// Internal method to execute a query and return raw result
  Future<dynamic> _executeQueryRaw(SqfliteQuery query) async {
    // Find fixture data
    final fixtureData = await dataQuery.find(query);
    if (fixtureData == null) {
      return null;
    }

    // Parse into collection
    final collection = await dataQuery.parse(fixtureData);
    if (collection == null) {
      return null;
    }

    // Select a fixture
    final selected = await dataQuery.select(
      collection,
      dataSelectorView,
      dataSelector,
      delay: delay,
    );

    if (selected == null) {
      return null;
    }

    // Get the data - return the raw data, not wrapped
    if (selected.data != null) {
      return selected.data;
    }

    // Load from dataPath if specified
    final result = await dataQuery.data(selected);
    if (result != null && result.containsKey('result')) {
      return result['result'];
    }
    return result;
  }
}

/// Backwards-compatible alias for [FixtureDatabaseAdapter].
///
/// @Deprecated('Use FixtureDatabaseAdapter instead')
typedef FixtureDatabase = FixtureDatabaseAdapter;
