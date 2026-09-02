import 'dart:async';

import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// A source keyed by request string: the pipeline is exercised entirely
/// through its interface, with the source as the only collaborator.
class _FakeSource implements FixtureSource<String> {
  _FakeSource({this.collections = const {}, this.payloads = const {}});

  final Map<String, FixtureCollection> collections;
  final Map<String, Object?> payloads;

  @override
  Future<FixtureCollection?> resolve(String request) async =>
      collections[request];

  @override
  Future<Object?> data(FixtureDocument document) async =>
      payloads[document.identifier];
}

class _FakeView implements DataSelectorView {
  _FakeView(this._onPick);

  final Future<FixtureChoice?> Function(FixtureCollection fixture) _onPick;
  int pickCount = 0;

  @override
  Future<FixtureChoice?> pick(FixtureCollection fixture) {
    pickCount++;
    return _onPick(fixture);
  }
}

FixtureCollection _twoOptions() => FixtureCollection(
      description: 'Users API',
      items: [
        FixtureDocument(
          identifier: 'ok',
          description: '200 OK',
          defaultOption: true,
          data: {},
        ),
        FixtureDocument(
          identifier: 'not_found',
          description: '404 Not Found',
          defaultOption: false,
          data: {},
        ),
      ],
    );

FixturePipeline<String> _pipeline({
  FixtureCollection? collection,
  Map<String, Object?> payloads = const {},
  DataSelectorType selector = DataSelectorType.pick,
  DataSelectorView? view,
}) {
  return FixturePipeline(
    source: _FakeSource(
      collections: collection == null ? {} : {'/users': collection},
      payloads: payloads,
    ),
    selector: selector,
    view: view,
  );
}

/// The identifier of the document a served outcome selected.
Future<String?> _servedId(FixturePipeline<String> pipeline) async {
  final outcome = await pipeline.serve('/users');
  return outcome is FixtureServed ? outcome.document.identifier : null;
}

void main() {
  group('FixturePipeline.serve outcomes', () {
    test('reports not found when the source has no collection', () async {
      expect(await _pipeline().serve('/users'), isA<FixtureNotFound>());
    });

    test('reports empty when the collection has no documents', () async {
      final pipeline = _pipeline(
        collection: FixtureCollection(description: 'Empty', items: []),
      );
      expect(await pipeline.serve('/users'), isA<FixtureEmpty>());
    });

    test('reports cancelled when the user dismisses the pick', () async {
      final pipeline = _pipeline(
        collection: _twoOptions(),
        view: _FakeView((_) async => null),
      );
      expect(await pipeline.serve('/users'), isA<FixtureCancelled>());
    });

    test('serves the selected document with its payload', () async {
      final pipeline = _pipeline(
        collection: _twoOptions(),
        payloads: {'ok': 'payload for ok'},
        selector: DataSelectorType.defaultValue,
      );

      final outcome = await pipeline.serve('/users');

      expect(outcome, isA<FixtureServed>());
      final served = outcome as FixtureServed;
      expect(served.document.identifier, 'ok');
      expect(served.payload, 'payload for ok');
    });

    test('a miss is throwable and carries its message', () {
      const miss = FixtureCancelled();
      expect(miss, isA<Exception>());
      expect(miss.toString(), miss.message);
      expect(() => throw miss, throwsA(isA<FixtureCancelled>()));
    });
  });

  group('selection strategy', () {
    test('auto-selects a single option without consulting the view', () async {
      final single = FixtureCollection(
        description: 'Single',
        items: [
          FixtureDocument(
            identifier: 'only',
            description: '200 OK',
            defaultOption: true,
            data: {},
          ),
        ],
      );
      for (final selector in DataSelectorType.values) {
        final view = _FakeView((_) async => null);
        final pipeline =
            _pipeline(collection: single, selector: selector, view: view);
        expect(await _servedId(pipeline), 'only');
        expect(view.pickCount, 0);
      }
    });

    test('pick without a view falls back to the first document', () async {
      expect(await _servedId(_pipeline(collection: _twoOptions())), 'ok');
    });

    test('pick serves the document chosen through the view', () async {
      final view = _FakeView((f) async => FixtureChoice(document: f.items[1]));
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      expect(await _servedId(pipeline), 'not_found');

      // Not remembered: a later request consults the view again.
      await pipeline.serve('/users');
      expect(view.pickCount, 2);
    });

    test('default serves the document marked as default', () async {
      final pipeline = _pipeline(
        collection: _twoOptions(),
        selector: DataSelectorType.defaultValue,
      );
      expect(await _servedId(pipeline), 'ok');
    });

    test('default throws when nothing is marked default', () async {
      final pipeline = _pipeline(
        collection: FixtureCollection(
          description: 'No default',
          items: [
            FixtureDocument(
                identifier: 'a', description: '200', defaultOption: false),
            FixtureDocument(
                identifier: 'b', description: '400', defaultOption: false),
          ],
        ),
        selector: DataSelectorType.defaultValue,
      );
      expect(() => pipeline.serve('/users'), throwsA(isA<StateError>()));
    });
  });

  group('Selection Memory', () {
    test('a remembered choice answers later requests without the view',
        () async {
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      await pipeline.serve('/users');
      expect(await _servedId(pipeline), 'not_found');
      expect(view.pickCount, 1);
    });

    test('clearing memory makes the next pick interactive again', () async {
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      await pipeline.serve('/users');
      pipeline.clearRememberedSelectionFor(_twoOptions());
      await pipeline.serve('/users');

      expect(view.pickCount, 2);
    });

    test('clearing all memory forgets every collection', () async {
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      await pipeline.serve('/users');
      pipeline.clearRememberedSelections();
      await pipeline.serve('/users');

      expect(view.pickCount, 2);
    });

    test('memory is scoped to the pipeline instance', () async {
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );

      await _pipeline(collection: _twoOptions(), view: view).serve('/users');
      await _pipeline(collection: _twoOptions(), view: view).serve('/users');

      expect(view.pickCount, 2);
    });
  });

  group('single-flight picks', () {
    test('concurrent requests for the same collection share one pick',
        () async {
      final completer = Completer<FixtureChoice?>();
      final view = _FakeView((_) => completer.future);
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      final first = pipeline.serve('/users');
      final second = pipeline.serve('/users');

      // Let both requests reach the view.
      await Future<void>.delayed(Duration.zero);
      expect(view.pickCount, 1);

      completer.complete(FixtureChoice(document: _twoOptions().items[1]));
      final results = await Future.wait([first, second]);
      for (final outcome in results) {
        expect((outcome as FixtureServed).document.identifier, 'not_found');
      }
    });

    test('a new pick is allowed after the previous one completes', () async {
      final view =
          _FakeView((f) async => FixtureChoice(document: f.items.first));
      final pipeline = _pipeline(collection: _twoOptions(), view: view);

      await pipeline.serve('/users');
      await pipeline.serve('/users');

      expect(view.pickCount, 2);
    });
  });

  group('delay', () {
    test('is applied before a served response', () async {
      final pipeline = FixturePipeline(
        source: _FakeSource(collections: {'/users': _twoOptions()}),
        selector: DataSelectorType.defaultValue,
        delay: const Duration(milliseconds: 40),
      );

      final stopwatch = Stopwatch()..start();
      await pipeline.serve('/users');

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(35));
    });
  });
}
