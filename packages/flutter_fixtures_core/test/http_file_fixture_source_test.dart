import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

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
  group('HttpFileFixtureSource.resolve', () {
    test('matches {METHOD}_{PATH} with no query params', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/GET_users.json': _emptyCollection,
      });
      final source = HttpFileFixtureSource(assetLoader: loader);

      final result = await source.resolve(
        const HttpFixtureRequest(method: 'GET', path: '/users'),
      );

      expect(result!['description'], equals('found'));
      expect(loader.requestedPaths, equals(['assets/fixtures/GET_users.json']));
    });

    test('tries candidates in priority order: exact, values, *, {{key}}',
        () async {
      final loader = InMemoryAssetLoader({});
      final source = HttpFileFixtureSource(assetLoader: loader);

      await source.resolve(const HttpFixtureRequest(
        method: 'GET',
        path: '/search',
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

    test('respects a custom mock folder', () async {
      final loader = InMemoryAssetLoader({
        'custom/mocks/GET_users.json': _emptyCollection,
      });
      final source = HttpFileFixtureSource(
          mockFolder: 'custom/mocks', assetLoader: loader);

      final result = await source.resolve(
        const HttpFixtureRequest(method: 'GET', path: '/users'),
      );

      expect(result, isNotNull);
    });
  });

  group('HttpFileFixtureSource.data', () {
    test('loads external data relative to the mock folder', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/data/users.json': '[{"id": 1}]',
      });
      final source = HttpFileFixtureSource(assetLoader: loader);

      final result = await source.data(FixtureDocument(
        identifier: 'ok',
        description: '200',
        defaultOption: false,
        dataPath: 'data/users.json',
      ));

      expect(result, isA<List>());
    });
  });
}
