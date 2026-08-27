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

        expect(result, isNotNull);
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

    group('constructor', () {
      test('uses default mock folder', () {
        final dataQuery = SqfliteDataQuery();
        expect(dataQuery.mockFolderPath, 'assets/fixtures/database');
      });

      test('accepts custom mock folder', () {
        final dataQuery = SqfliteDataQuery(mockFolder: 'custom/path');
        expect(dataQuery.mockFolderPath, 'custom/path');
      });
    });

    group('parse', () {
      late SqfliteDataQuery dataQuery;

      setUp(() {
        dataQuery = SqfliteDataQuery();
      });

      test('parses fixture data with single item', () async {
        final source = {
          'description': 'User fixtures',
          'values': [
            {
              'identifier': 'success',
              'description': 'Returns users',
              'default': true,
              'data': [
                {'id': 1, 'name': 'John'}
              ],
            },
          ],
        };

        final collection = await dataQuery.parse(source);

        expect(collection, isNotNull);
        expect(collection!.description, 'User fixtures');
        expect(collection.items, hasLength(1));
        expect(collection.items[0].identifier, 'success');
        expect(collection.items[0].description, 'Returns users');
        expect(collection.items[0].defaultOption, true);
        expect(collection.items[0].data, isA<List>());
      });

      test('parses fixture data with multiple items', () async {
        final source = {
          'description': 'User fixtures',
          'values': [
            {
              'identifier': 'success',
              'description': 'Returns users',
              'default': true,
              'data': [
                {'id': 1, 'name': 'John'}
              ],
            },
            {
              'identifier': 'empty',
              'description': 'Empty result',
              'data': [],
            },
            {
              'identifier': 'error',
              'description': 'Database error',
              'data': null,
              'dataPath': 'errors/db_error.json',
            },
          ],
        };

        final collection = await dataQuery.parse(source);

        expect(collection, isNotNull);
        expect(collection!.items, hasLength(3));
        expect(collection.items[0].identifier, 'success');
        expect(collection.items[1].identifier, 'empty');
        expect(collection.items[1].defaultOption, false);
        expect(collection.items[2].identifier, 'error');
        expect(collection.items[2].dataPath, 'errors/db_error.json');
      });

      test('handles missing description', () async {
        final source = {
          'values': [
            {
              'identifier': 'test',
              'description': 'Test fixture',
              'data': {'key': 'value'},
            },
          ],
        };

        final collection = await dataQuery.parse(source);

        expect(collection, isNotNull);
        expect(collection!.description, '');
      });
    });

    group('data', () {
      late SqfliteDataQuery dataQuery;

      setUp(() {
        dataQuery = SqfliteDataQuery();
      });

      test('returns null when document has no data or dataPath', () async {
        final document = FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
          data: null,
          dataPath: null,
        );

        final result = await dataQuery.data(document);
        expect(result, isNull);
      });

      test('returns inline data wrapped in result for List', () async {
        final document = FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
          data: [
            {'id': 1, 'name': 'John'}
          ],
        );

        final result = await dataQuery.data(document);

        expect(result, isNotNull);
        expect(result!['result'], isA<List>());
        expect((result['result'] as List)[0]['name'], 'John');
      });

      test('returns inline data as-is for Map', () async {
        final document = FixtureDocument(
          identifier: 'test',
          description: 'Test',
          defaultOption: false,
          data: {'insertId': 42},
        );

        final result = await dataQuery.data(document);

        expect(result, isNotNull);
        expect(result!['insertId'], 42);
      });

      test('a document cannot be built with both data and dataPath', () {
        expect(
          () => FixtureDocument(
            identifier: 'test',
            description: 'Test',
            defaultOption: false,
            data: {'key': 'value'},
            dataPath: 'some/path.json',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
