import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake fixture source substituted at the FixtureDatabaseAdapter seam.
class FakeFixtureSource implements SqfliteFixtureSource {
  FakeFixtureSource({this.collection, this.payload});

  final FixtureCollection? collection;
  final Object? payload;

  @override
  Future<FixtureCollection?> resolve(SqfliteQuery query) async => collection;

  @override
  Future<Object?> data(FixtureDocument document) async => payload;
}

FixtureCollection _singleDocument() => FixtureCollection(
      description: 'db fixture',
      items: [
        FixtureDocument(
          identifier: 'success',
          description: 'Returns rows',
          defaultOption: true,
        ),
      ],
    );

FixtureDatabaseAdapter _db({
  FixtureCollection? collection,
  Object? payload,
}) {
  return FixtureDatabaseAdapter(
    dataQuery: FakeFixtureSource(collection: collection, payload: payload),
    dataSelector: DataSelectorType.defaultValue,
  );
}

void main() {
  group('FixtureDatabaseAdapter', () {
    group('query', () {
      test('returns empty list when no fixture found', () async {
        final result = await _db().query('users');

        expect(result, isEmpty);
      });

      test('returns empty list when the collection has no documents', () async {
        final db = _db(
          collection: FixtureCollection(description: 'empty', items: []),
        );

        final result = await db.query('users');

        expect(result, isEmpty);
      });

      test('returns list payloads as rows', () async {
        final db = _db(
          collection: _singleDocument(),
          payload: [
            {'id': 1, 'name': 'John'},
            {'id': 2, 'name': 'Jane'},
          ],
        );

        final result = await db.query('users');

        expect(result, hasLength(2));
        expect(result.first['name'], equals('John'));
      });

      test('unwraps result-keyed payloads into rows', () async {
        final db = _db(
          collection: _singleDocument(),
          payload: {
            'result': [
              {'id': 1, 'name': 'John'},
              {'id': 2, 'name': 'Jane'},
            ],
          },
        );

        final result = await db.query('users');

        expect(result, hasLength(2));
        expect(result.first['name'], equals('John'));
      });

      test('wraps a single-row map payload into one row', () async {
        final db = _db(
          collection: _singleDocument(),
          payload: {'id': 1, 'name': 'John'},
        );

        final result = await db.query('users');

        expect(result, hasLength(1));
        expect(result.single['id'], equals(1));
      });
    });

    group('insert', () {
      test('returns default id of 1 when no fixture found', () async {
        final result = await _db().insert('users', {'name': 'John'});

        expect(result, 1);
      });

      test('returns the insertId provided by the fixture', () async {
        final db = _db(
          collection: _singleDocument(),
          payload: {'insertId': 42},
        );

        final result = await db.insert('users', {'name': 'John'});

        expect(result, 42);
      });
    });

    group('update', () {
      test('returns default affected rows of 1 when no fixture found',
          () async {
        final result = await _db().update(
          'users',
          {'name': 'Jane'},
          where: 'id = ?',
        );

        expect(result, 1);
      });

      test('returns the affectedRows provided by the fixture', () async {
        final db = _db(
          collection: _singleDocument(),
          payload: {'affectedRows': 3},
        );

        final result =
            await db.update('users', {'name': 'Jane'}, where: 'id = ?');

        expect(result, 3);
      });
    });

    group('delete', () {
      test('returns default affected rows of 1 when no fixture found',
          () async {
        final result = await _db().delete('users', where: 'id = ?');

        expect(result, 1);
      });
    });

    group('rawQuery', () {
      test('returns empty list when no fixture found', () async {
        final result = await _db().rawQuery('SELECT * FROM users');

        expect(result, isEmpty);
      });
    });
  });
}
