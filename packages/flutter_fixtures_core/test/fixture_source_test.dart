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

void main() {
  group('FixtureSource.resolve', () {
    test('returns the first candidate that exists', () async {
      final loader = InMemoryAssetLoader({
        'fixtures/b.json': '{"description": "B", "values": []}',
        'fixtures/c.json': '{"description": "C", "values": []}',
      });
      final source = FixtureSource(mockFolder: 'fixtures', assetLoader: loader);

      final result = await source.resolve(['a.json', 'b.json', 'c.json']);

      expect(result!['description'], equals('B'));
      expect(
        loader.requestedPaths,
        equals(['fixtures/a.json', 'fixtures/b.json']),
      );
    });

    test('returns null when no candidate exists', () async {
      final source = FixtureSource(
        mockFolder: 'fixtures',
        assetLoader: InMemoryAssetLoader({}),
      );

      expect(await source.resolve(['a.json', 'b.json']), isNull);
    });

    test('malformed JSON in a matched candidate fails loudly', () async {
      final loader = InMemoryAssetLoader({
        'fixtures/a.json': '{not json',
      });
      final source = FixtureSource(mockFolder: 'fixtures', assetLoader: loader);

      expect(
        () => source.resolve(['a.json']),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('FixtureSource.data', () {
    test('returns inline data as-is', () async {
      final source = FixtureSource(
        mockFolder: 'fixtures',
        assetLoader: InMemoryAssetLoader({}),
      );
      final document = FixtureDocument(
        identifier: 'inline',
        description: '200',
        defaultOption: false,
        data: {'a': 1},
      );

      expect(await source.data(document), equals({'a': 1}));
    });

    test('loads and decodes external data, including JSON arrays', () async {
      final loader = InMemoryAssetLoader({
        'fixtures/data/users.json': '[{"id": 1}, {"id": 2}]',
      });
      final source = FixtureSource(mockFolder: 'fixtures', assetLoader: loader);
      final document = FixtureDocument(
        identifier: 'external',
        description: '200',
        defaultOption: false,
        dataPath: 'data/users.json',
      );

      final result = await source.data(document);
      expect(result, isA<List>());
      expect((result as List).first, equals({'id': 1}));
    });

    test('returns null for a document with no payload', () async {
      final source = FixtureSource(
        mockFolder: 'fixtures',
        assetLoader: InMemoryAssetLoader({}),
      );
      final document = FixtureDocument(
        identifier: 'empty',
        description: '204',
        defaultOption: false,
      );

      expect(await source.data(document), isNull);
    });
  });
}
