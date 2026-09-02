import 'package:sqflite/sqflite.dart' as sqflite;

import 'sqflite_query.dart';
import 'statement_database_adapter.dart';

/// The production [StatementDatabaseAdapter]: runs each statement against
/// a real sqflite [sqflite.Database].
///
/// ```dart
/// final db = RealDatabaseAdapter(await openDatabase('app.db'));
/// final repo = UserRepository(db);
/// ```
class RealDatabaseAdapter extends StatementDatabaseAdapter {
  final sqflite.Database _database;

  RealDatabaseAdapter(this._database);

  /// The underlying sqflite database.
  sqflite.Database get database => _database;

  @override
  Future<Object?> run(SqfliteQuery statement) {
    final s = statement;
    return switch (s.operation) {
      SqfliteOperation.query => _database.query(
          s.table!,
          distinct: s.distinct,
          columns: s.columns,
          where: s.where,
          whereArgs: s.arguments,
          groupBy: s.groupBy,
          having: s.having,
          orderBy: s.orderBy,
          limit: s.limit,
          offset: s.offset,
        ),
      SqfliteOperation.rawQuery => _database.rawQuery(s.sql!, s.arguments),
      SqfliteOperation.insert => _database.insert(
          s.table!,
          s.values!,
          nullColumnHack: s.nullColumnHack,
          conflictAlgorithm: _conflict(s.conflictAlgorithm),
        ),
      SqfliteOperation.update => _database.update(
          s.table!,
          s.values!,
          where: s.where,
          whereArgs: s.arguments,
          conflictAlgorithm: _conflict(s.conflictAlgorithm),
        ),
      SqfliteOperation.delete => _database.delete(
          s.table!,
          where: s.where,
          whereArgs: s.arguments,
        ),
      SqfliteOperation.rawInsert => _database.rawInsert(s.sql!, s.arguments),
      SqfliteOperation.rawUpdate => _database.rawUpdate(s.sql!, s.arguments),
      SqfliteOperation.rawDelete => _database.rawDelete(s.sql!, s.arguments),
      SqfliteOperation.execute => _database.execute(s.sql!, s.arguments),
    };
  }

  static sqflite.ConflictAlgorithm? _conflict(String? name) =>
      name == null ? null : sqflite.ConflictAlgorithm.values.byName(name);

  @override
  Future<void> close() => _database.close();

  @override
  bool get isOpen => _database.isOpen;
}
