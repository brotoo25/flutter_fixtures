import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// A source with canned answers and counted calls.
class FakeSource implements HttpFixtureSource {
  FixtureCollection? collection;
  final Object? payload;
  int resolveCalls = 0;
  int dataCalls = 0;

  FakeSource({this.collection, this.payload});

  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    resolveCalls++;
    return collection;
  }

  @override
  Future<Object?> data(FixtureDocument document) async {
    dataCalls++;
    return payload;
  }
}

FixtureCollection collection(String description) {
  return FixtureCollection(
    description: description,
    items: [
      FixtureDocument(
        identifier: 'doc-$description',
        description: '200 OK',
        defaultOption: true,
        data: null,
      ),
    ],
  );
}

const request = HttpFixtureRequest(method: 'GET', path: '/users');

void main() {
  group('HttpFixtureSources', () {
    test('the first source that resolves wins', () async {
      final first = FakeSource(collection: collection('first'));
      final second = FakeSource(collection: collection('second'));
      final sources = HttpFixtureSources([first, second]);

      final resolved = await sources.resolve(request);

      expect(resolved!.description, 'first');
      expect(second.resolveCalls, 0);
    });

    test('falls through non-resolving sources in order', () async {
      final empty = FakeSource();
      final winner = FakeSource(collection: collection('winner'));
      final sources = HttpFixtureSources([empty, winner]);

      final resolved = await sources.resolve(request);

      expect(resolved!.description, 'winner');
      expect(empty.resolveCalls, 1);
    });

    test('resolves null when no source has a fixture', () async {
      final sources = HttpFixtureSources([FakeSource(), FakeSource()]);
      expect(await sources.resolve(request), isNull);
    });

    test('the resolving source provides the payload, not earlier sources',
        () async {
      final empty = FakeSource(payload: 'wrong');
      final winner = FakeSource(
        collection: collection('winner'),
        payload: 'right',
      );
      final sources = HttpFixtureSources([empty, winner]);

      final resolved = await sources.resolve(request);
      final payload = await sources.data(resolved!.items.single);

      expect(payload, 'right');
      expect(empty.dataCalls, 0);
    });

    test('concurrent resolves do not cross wires', () async {
      final a = FakeSource(collection: collection('a'), payload: 'from a');
      final b = FakeSource(payload: 'from b');
      final sourcesA = HttpFixtureSources([a, b]);

      // Interleave: resolve two requests before asking for either payload.
      final resolvedFirst = await sourcesA.resolve(request);
      final resolvedSecond = await sourcesA
          .resolve(const HttpFixtureRequest(method: 'GET', path: '/other'));

      expect(await sourcesA.data(resolvedFirst!.items.single), 'from a');
      expect(await sourcesA.data(resolvedSecond!.items.single), 'from a');
    });

    test('a source may reuse its own cached documents across resolves',
        () async {
      final cached = collection('cached');
      final caching = FakeSource(collection: cached, payload: 'cached');
      final sources = HttpFixtureSources([caching]);

      final first = await sources.resolve(request);
      final second = await sources.resolve(request);

      expect(identical(first, second), isTrue);
      expect(await sources.data(second!.items.single), 'cached');
    });

    test('a document instance shared by two sources fails loudly', () async {
      final shared = collection('shared');
      final first = FakeSource(collection: shared);
      final second = FakeSource(collection: shared);
      final sources = HttpFixtureSources([first, second]);

      // Request 1: `first` wins and owns the shared documents.
      await sources.resolve(request);

      // Request 2: `first` no longer resolves, so the SAME document
      // instance arrives through `second` — ambiguous, rejected loudly
      // instead of silently rerouting request 1's payload.
      first.collection = null;
      expect(() => sources.resolve(request), throwsStateError);
    });

    test('data() for a document it never resolved fails loudly', () async {
      final sources = HttpFixtureSources([FakeSource()]);
      final stray = FixtureDocument(
        identifier: 'stray',
        description: '200',
        defaultOption: false,
        data: null,
      );

      expect(() => sources.data(stray), throwsStateError);
    });
  });
}
