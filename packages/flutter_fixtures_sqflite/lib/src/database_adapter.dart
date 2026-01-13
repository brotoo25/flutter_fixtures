import 'package:sqflite/sqflite.dart' as sqflite;

/// An abstract database adapter that mirrors sqflite's Database API.
///
/// This allows you to swap between a real sqflite database and fixture-based
/// mocking with zero changes to your repository/DAO code.
///
/// ## Usage
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
/// final repo = UserRepository(db);
///
/// // In development/testing:
/// final db = FixtureDatabaseAdapter(
///   dataQuery: SqfliteDataQuery(),
///   dataSelector: DataSelectorType.pick(),
/// );
/// final repo = UserRepository(db);
/// ```
abstract class DatabaseAdapter {
  /// Query a table and return rows as a list of maps.
  ///
  /// Equivalent to sqflite's `Database.query()`.
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
  });

  /// Execute a raw SQL query.
  ///
  /// Equivalent to sqflite's `Database.rawQuery()`.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  /// Insert a row into a table.
  ///
  /// Returns the row ID of the inserted row.
  /// Equivalent to sqflite's `Database.insert()`.
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  });

  /// Update rows in a table.
  ///
  /// Returns the number of affected rows.
  /// Equivalent to sqflite's `Database.update()`.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  });

  /// Delete rows from a table.
  ///
  /// Returns the number of affected rows.
  /// Equivalent to sqflite's `Database.delete()`.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  /// Execute a raw SQL INSERT statement.
  ///
  /// Returns the row ID of the inserted row.
  Future<int> rawInsert(String sql, [List<Object?>? arguments]);

  /// Execute a raw SQL UPDATE statement.
  ///
  /// Returns the number of affected rows.
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]);

  /// Execute a raw SQL DELETE statement.
  ///
  /// Returns the number of affected rows.
  Future<int> rawDelete(String sql, [List<Object?>? arguments]);

  /// Execute a raw SQL statement (for DDL, etc.).
  Future<void> execute(String sql, [List<Object?>? arguments]);

  /// Close the database connection.
  Future<void> close();

  /// Whether the database is open.
  bool get isOpen;
}
