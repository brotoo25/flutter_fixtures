import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryAssetLoader implements FixtureAssetLoader {
  InMemoryAssetLoader(this.files);

  final Map<String, String> files;
  final List<String> requestedPaths = [];

  @override
  Future<String> load(String path) async {
    requestedPaths.add(path);
    final content = files[path];
    if (content == null) {
      throw StateError('Asset not found: $path');
    }
    return content;
  }
}

void main() {
  group('SqfliteDataQuery', () {
    group('find', () {
      const collectionJson = '{"description": "found", "values": []}';

      test('matches {operation}_{table} for table queries', () async {
        final loader = InMemoryAssetLoader({
          'assets/fixtures/database/query_users.json': collectionJson,
        });
        final dataQuery = SqfliteDataQuery(assetLoader: loader);

        final result = await dataQuery.find(const SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
        ));

        expect(result!.description, equals('found'));
        expect(
          loader.requestedPaths,
          equals(['assets/fixtures/database/query_users.json']),
        );
      });

      test(
          'falls back to the table fixture when the where-clause candidate '
          'is missing', () async {
        final loader = InMemoryAssetLoader({
          'assets/fixtures/database/query_users.json': collectionJson,
        });
        final dataQuery = SqfliteDataQuery(assetLoader: loader);

        final result = await dataQuery.find(const SqfliteQuery.table(
          table: 'users',
          operation: SqfliteOperation.query,
          where: 'id = 1',
        ));

        expect(result, isNotNull);
        expect(
          loader.requestedPaths,
          equals([
            'assets/fixtures/database/query_users_id__1.json',
            'assets/fixtures/database/query_users.json',
          ]),
        );
      });

      test('returns null when nothing matches', () async {
        final dataQuery = SqfliteDataQuery(
          assetLoader: InMemoryAssetLoader({}),
        );

        final result = await dataQuery.find(const SqfliteQuery.table(
          table: 'missing',
          operation: SqfliteOperation.query,
        ));

        expect(result, isNull);
      });
    });

    group('data', () {
      test('returns null when document has no data or dataPath', () async {
        final dataQuery = SqfliteDataQuery(
          assetLoader: InMemoryAssetLoader({}),
        );

        final result = await dataQuery.data(FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
        ));

        expect(result, isNull);
      });

      test('returns inline data as-is', () async {
        final dataQuery = SqfliteDataQuery(
          assetLoader: InMemoryAssetLoader({}),
        );

        final rows = [
          {'id': 1, 'name': 'John'}
        ];
        final result = await dataQuery.data(FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
          data: rows,
        ));

        expect(result, equals(rows));
      });

      test('loads external data relative to the mock folder', () async {
        final loader = InMemoryAssetLoader({
          'assets/fixtures/database/data/users.json': '[{"id": 1}]',
        });
        final dataQuery = SqfliteDataQuery(assetLoader: loader);

        final result = await dataQuery.data(FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
          dataPath: 'data/users.json',
        ));

        expect(
          result,
          equals([
            {'id': 1}
          ]),
        );
      });
    });
  });
}
