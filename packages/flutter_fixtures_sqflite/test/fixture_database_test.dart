import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake DataQuery substituted at the FixtureDatabaseAdapter seam.
class FakeDataQuery
    with FixtureSelector
    implements DataQuery<SqfliteQuery, Map<String, dynamic>> {
  Map<String, dynamic>? findResult;
  FixtureCollection? parseResult;
  Map<String, dynamic>? dataResult;

  @override
  Future<Map<String, dynamic>?> find(SqfliteQuery input) async {
    return findResult;
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    return parseResult;
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    return dataResult;
  }
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

void main() {
  group('FixtureDatabase', () {
    group('constructor', () {
      test('creates database with required parameters', () {
        final db = FixtureDatabase(
          dataQuery: SqfliteDataQuery(),
          dataSelector: DataSelectorType.defaultValue(),
        );

        expect(db.dataQuery, isNotNull);
        expect(db.dataSelector, isNotNull);
        expect(db.dataSelectorView, isNull);
        expect(db.delay, DataSelectorDelay.instant);
      });

      test('creates database with all parameters', () {
        final db = FixtureDatabase(
          dataQuery: SqfliteDataQuery(),
          dataSelector: DataSelectorType.random(),
          dataSelectorView: null,
          delay: DataSelectorDelay.fast,
        );

        expect(db.delay, DataSelectorDelay.fast);
      });
    });

    group('query', () {
      test('returns empty list when no fixture found', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, isEmpty);
      });

      test('returns empty list when parse returns null', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = {'values': []};
        fakeDataQuery.parseResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, isEmpty);
      });

      test('unwraps result-keyed payloads into rows', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = {'values': []};
        fakeDataQuery.parseResult = _singleDocument();
        fakeDataQuery.dataResult = {
          'result': [
            {'id': 1, 'name': 'John'},
            {'id': 2, 'name': 'Jane'},
          ],
        };

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, hasLength(2));
        expect(result.first['name'], equals('John'));
      });

      test('wraps a single-row map payload into one row', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = {'values': []};
        fakeDataQuery.parseResult = _singleDocument();
        fakeDataQuery.dataResult = {'id': 1, 'name': 'John'};

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, hasLength(1));
        expect(result.single['id'], equals(1));
      });
    });

    group('insert', () {
      test('returns default id of 1 when no fixture found', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.insert('users', {'name': 'John'});

        expect(result, 1);
      });

      test('returns the insertId provided by the fixture', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = {'values': []};
        fakeDataQuery.parseResult = _singleDocument();
        fakeDataQuery.dataResult = {'insertId': 42};

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.insert('users', {'name': 'John'});

        expect(result, 42);
      });
    });

    group('update', () {
      test('returns default affected rows of 1 when no fixture found',
          () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.update(
          'users',
          {'name': 'Jane'},
          where: 'id = ?',
        );

        expect(result, 1);
      });

      test('returns the affectedRows provided by the fixture', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = {'values': []};
        fakeDataQuery.parseResult = _singleDocument();
        fakeDataQuery.dataResult = {'affectedRows': 3};

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result =
            await db.update('users', {'name': 'Jane'}, where: 'id = ?');

        expect(result, 3);
      });
    });

    group('delete', () {
      test('returns default affected rows of 1 when no fixture found',
          () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.delete('users', where: 'id = ?');

        expect(result, 1);
      });
    });

    group('rawQuery', () {
      test('returns empty list when no fixture found', () async {
        final fakeDataQuery = FakeDataQuery();
        fakeDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: fakeDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.rawQuery('SELECT * FROM users');

        expect(result, isEmpty);
      });
    });
  });
}
