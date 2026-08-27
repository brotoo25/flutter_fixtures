import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_dio/flutter_fixtures_dio.dart';

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

const _emptyCollection = '{"description": "found", "values": []}';

void main() {
  group('DioDataQuery.find', () {
    test('matches {METHOD}_{PATH} with no query params', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/GET_users.json': _emptyCollection,
      });
      final query = DioDataQuery(assetLoader: loader);

      final result = await query.find(
        RequestOptions(path: '/users', method: 'GET'),
      );

      expect(result, isNotNull);
      expect(loader.requestedPaths, equals(['assets/fixtures/GET_users.json']));
    });

    test('tries candidates in priority order: exact, values, *, {{key}}',
        () async {
      final loader = InMemoryAssetLoader({});
      final query = DioDataQuery(assetLoader: loader);

      await query.find(RequestOptions(
        path: '/search',
        method: 'GET',
        queryParameters: {'q': 'test', 'page': 2},
      ));

      expect(
        loader.requestedPaths,
        equals([
          'assets/fixtures/GET_search.json',
          'assets/fixtures/GET_search_2_test.json',
          'assets/fixtures/GET_search_*_*.json',
          'assets/fixtures/GET_search_{{page}}_{{q}}.json',
        ]),
      );
    });

    test('orders query values by sorted key name, not URL order', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/GET_search_2_test.json': _emptyCollection,
      });
      final query = DioDataQuery(assetLoader: loader);

      final result = await query.find(RequestOptions(
        path: '/search',
        method: 'GET',
        queryParameters: {'q': 'test', 'page': 2},
      ));

      expect(result, isNotNull);
    });

    test('normalizes slashes and spaces in query values', () async {
      final loader = InMemoryAssetLoader({});
      final query = DioDataQuery(assetLoader: loader);

      await query.find(RequestOptions(
        path: '/files',
        method: 'GET',
        queryParameters: {'name': 'my file/one'},
      ));

      expect(
        loader.requestedPaths,
        contains('assets/fixtures/GET_files_my_file_one.json'),
      );
    });

    test('returns null when nothing matches', () async {
      final query = DioDataQuery(assetLoader: InMemoryAssetLoader({}));

      final result = await query.find(
        RequestOptions(path: '/missing', method: 'GET'),
      );

      expect(result, isNull);
    });

    test('respects a custom mock folder', () async {
      final loader = InMemoryAssetLoader({
        'custom/mocks/POST_login.json': _emptyCollection,
      });
      final query =
          DioDataQuery(mockFolder: 'custom/mocks', assetLoader: loader);

      final result = await query.find(
        RequestOptions(path: '/login', method: 'POST'),
      );

      expect(result, isNotNull);
    });
  });

  group('DioDataQuery.parse', () {
    test('parses the wire format into a FixtureCollection', () async {
      final query = DioDataQuery(assetLoader: InMemoryAssetLoader({}));

      final collection = await query.parse({
        'description': 'Users API',
        'values': [
          {'identifier': 'ok', 'description': '200 OK', 'default': true},
        ],
      });

      expect(collection!.description, equals('Users API'));
      expect(collection.items.single.statusCode, equals(200));
    });
  });

  group('DioDataQuery.data', () {
    test('loads external data relative to the mock folder', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/data/users.json': '[{"id": 1}]',
      });
      final query = DioDataQuery(assetLoader: loader);

      final result = await query.data(FixtureDocument(
        identifier: 'ok',
        description: '200',
        defaultOption: false,
        dataPath: 'data/users.json',
      ));

      expect(result, isA<List>());
    });
  });
}
