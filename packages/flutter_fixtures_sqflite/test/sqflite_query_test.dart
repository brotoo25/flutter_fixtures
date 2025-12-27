import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SqfliteQuery', () {
    group('table constructor', () {
      test('creates query with table and operation', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
        );

        expect(query.table, 'users');
        expect(query.operation, SqfliteOperation.query);
        expect(query.sql, isNull);
        expect(query.where, isNull);
        expect(query.columns, isNull);
      });

      test('creates query with where clause', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
          where: 'id = ?',
        );

        expect(query.table, 'users');
        expect(query.where, 'id = ?');
      });

      test('creates query with columns', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
          columns: ['id', 'name', 'email'],
        );

        expect(query.columns, ['id', 'name', 'email']);
      });

      test('creates insert query', () {
        const query = SqfliteQuery.table(
          table: 'orders',
          operation: SqfliteOperation.insert,
        );

        expect(query.operation, SqfliteOperation.insert);
        expect(query.table, 'orders');
      });

      test('creates update query with where', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.update,
          where: 'id = 1',
        );

        expect(query.operation, SqfliteOperation.update);
        expect(query.where, 'id = 1');
      });

      test('creates delete query', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.delete,
          where: 'status = "inactive"',
        );

        expect(query.operation, SqfliteOperation.delete);
        expect(query.where, 'status = "inactive"');
      });
    });

    group('raw constructor', () {
      test('creates raw SQL query', () {
        const query = SqfliteQuery.raw(
          sql: 'SELECT * FROM users WHERE id = 1',
        );

        expect(query.sql, 'SELECT * FROM users WHERE id = 1');
        expect(query.operation, SqfliteOperation.rawQuery);
        expect(query.table, isNull);
        expect(query.where, isNull);
        expect(query.columns, isNull);
      });
    });

    group('fixtureIdentifier', () {
      test('generates identifier for simple table query', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
        );

        expect(query.fixtureIdentifier, 'query_users');
      });

      test('generates identifier for insert operation', () {
        const query = SqfliteQuery.table(
          table: 'orders',
          operation: SqfliteOperation.insert,
        );

        expect(query.fixtureIdentifier, 'insert_orders');
      });

      test('generates identifier for update operation', () {
        const query = SqfliteQuery.table(
          table: 'products',
          operation: SqfliteOperation.update,
        );

        expect(query.fixtureIdentifier, 'update_products');
      });

      test('generates identifier for delete operation', () {
        const query = SqfliteQuery.table(
          table: 'sessions',
          operation: SqfliteOperation.delete,
        );

        expect(query.fixtureIdentifier, 'delete_sessions');
      });

      test('includes normalized where clause in identifier', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
          where: 'id = 1',
        );

        // 'id = 1' -> spaces become '_', '=' removed -> 'id__1'
        expect(query.fixtureIdentifier, 'query_users_id__1');
      });

      test('normalizes complex where clause', () {
        const query = SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
          where: 'status = "active" AND role = "admin"',
        );

        // Special chars removed, spaces become underscores
        expect(
          query.fixtureIdentifier,
          'query_users_status__active_AND_role__admin',
        );
      });

      test('generates identifier for raw SQL query', () {
        const query = SqfliteQuery.raw(
          sql: 'SELECT * FROM users',
        );

        expect(query.fixtureIdentifier, startsWith('rawQuery_'));
        expect(query.fixtureIdentifier, contains('select'));
      });
    });
  });
}
