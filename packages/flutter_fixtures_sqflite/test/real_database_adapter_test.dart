import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Conformance coverage for the swap seam's production adapter: the same
/// calls repositories make against [FixtureDatabaseAdapter] must work
/// against a real database.
void main() {
  late RealDatabaseAdapter db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    db = RealDatabaseAdapter(database);
    await db.execute(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    );
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
  });

  group('RealDatabaseAdapter', () {
    test('insert returns the row id and query returns the row', () async {
      final id = await db.insert('users', {'name': 'Alice'});

      expect(id, equals(1));
      final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['name'], equals('Alice'));
    });

    test('update and delete return affected row counts', () async {
      await db.insert('users', {'name': 'Alice'});
      await db.insert('users', {'name': 'Bob'});

      final updated = await db.update(
        'users',
        {'name': 'Al'},
        where: 'name = ?',
        whereArgs: ['Alice'],
      );
      expect(updated, equals(1));

      expect(await db.delete('users'), equals(2));
    });

    test('raw statements go through to the database', () async {
      expect(
        await db.rawInsert("INSERT INTO users (name) VALUES ('Cara')"),
        equals(1),
      );
      expect(
        await db.rawQuery('SELECT COUNT(*) AS n FROM users'),
        equals([
          {'n': 1}
        ]),
      );
      expect(await db.rawUpdate("UPDATE users SET name = 'C'"), equals(1));
      expect(await db.rawDelete('DELETE FROM users'), equals(1));
    });

    test('close closes the underlying database', () async {
      expect(db.isOpen, isTrue);

      await db.close();

      expect(db.isOpen, isFalse);
    });
  });
}
