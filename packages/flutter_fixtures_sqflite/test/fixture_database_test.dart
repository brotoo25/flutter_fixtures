import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mock implementation of SqfliteDataQuery for testing
class MockSqfliteDataQuery extends SqfliteDataQuery {
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
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, isEmpty);
      });

      test('returns empty list when parse returns null', () async {
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = {'values': []};
        mockDataQuery.parseResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.query('users');

        expect(result, isEmpty);
      });
    });

    group('insert', () {
      test('returns default id of 1 when no fixture found', () async {
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.insert('users', {'name': 'John'});

        expect(result, 1);
      });
    });

    group('update', () {
      test('returns default affected rows of 1 when no fixture found', () async {
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.update(
          'users',
          {'name': 'Jane'},
          where: 'id = ?',
        );

        expect(result, 1);
      });
    });

    group('delete', () {
      test('returns default affected rows of 1 when no fixture found', () async {
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.delete('users', where: 'id = ?');

        expect(result, 1);
      });
    });

    group('rawQuery', () {
      test('returns empty list when no fixture found', () async {
        final mockDataQuery = MockSqfliteDataQuery();
        mockDataQuery.findResult = null;

        final db = FixtureDatabase(
          dataQuery: mockDataQuery,
          dataSelector: DataSelectorType.defaultValue(),
        );

        final result = await db.rawQuery('SELECT * FROM users');

        expect(result, isEmpty);
      });
    });
  });
}

