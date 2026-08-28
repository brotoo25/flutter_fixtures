import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

class _Selector with FixtureSelector {}

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
            data: {}),
        FixtureDocument(
            identifier: 'not_found',
            description: '404 Not Found',
            defaultOption: false,
            data: {}),
      ],
    );

void main() {
  group('FixtureSelector', () {
    test('returns remembered document when selector is Pick', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );

      await selector.select(fixture, view, DataSelectorType.pick);

      // A later select — even without a view — returns the remembered pick.
      final selected =
          await selector.select(fixture, null, DataSelectorType.pick);
      expect(selected, isNotNull);
      expect(selected!.identifier, equals('not_found'));
    });

    test('auto-picks single option without UI', () async {
      final selector = _Selector();
      final single = FixtureCollection(
        description: 'Single',
        items: [
          FixtureDocument(
              identifier: 'only',
              description: '200 OK',
              defaultOption: true,
              data: {}),
        ],
      );

      final pickSel =
          await selector.select(single, null, DataSelectorType.pick);
      final defSel =
          await selector.select(single, null, DataSelectorType.defaultValue);
      final rndSel =
          await selector.select(single, null, DataSelectorType.random);

      expect(pickSel!.identifier, equals('only'));
      expect(defSel!.identifier, equals('only'));
      expect(rndSel!.identifier, equals('only'));
    });

    test('falls back to first item when Pick has no view', () async {
      final selector = _Selector();
      final selected =
          await selector.select(_twoOptions(), null, DataSelectorType.pick);
      expect(selected!.identifier, equals('ok'));
    });

    test('returns the document chosen through the view', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1]),
      );

      final selected =
          await selector.select(fixture, view, DataSelectorType.pick);
      expect(selected!.identifier, equals('not_found'));

      // Not remembered: a later select consults the view again.
      await selector.select(fixture, view, DataSelectorType.pick);
      expect(view.pickCount, equals(2));
    });

    test('writes memory when the choice asks to be remembered', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );

      await selector.select(fixture, view, DataSelectorType.pick);

      // A later select must not consult the view again.
      final second =
          await selector.select(fixture, view, DataSelectorType.pick);
      expect(second!.identifier, equals('not_found'));
      expect(view.pickCount, equals(1));
    });

    test('clearing memory makes the next pick interactive again', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );

      await selector.select(fixture, view, DataSelectorType.pick);
      selector.clearRememberedSelectionFor(fixture);

      await selector.select(fixture, view, DataSelectorType.pick);
      expect(view.pickCount, equals(2));
    });

    test('remembered choices are scoped to the selector instance', () async {
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items[1], remember: true),
      );

      await _Selector().select(fixture, view, DataSelectorType.pick);
      await _Selector().select(fixture, view, DataSelectorType.pick);

      expect(view.pickCount, equals(2));
    });

    test('propagates cancel as null instead of picking an item', () async {
      final selector = _Selector();
      final view = _FakeView((_) async => null);

      final selected =
          await selector.select(_twoOptions(), view, DataSelectorType.pick);
      expect(selected, isNull);
    });

    test('concurrent selects for the same collection share one pick', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final completer = Completer<FixtureChoice?>();
      final view = _FakeView((_) => completer.future);

      final first = selector.select(fixture, view, DataSelectorType.pick);
      final second = selector.select(fixture, view, DataSelectorType.pick);

      // Let both selects reach the view.
      await Future<void>.delayed(Duration.zero);
      expect(view.pickCount, equals(1));

      completer.complete(FixtureChoice(document: fixture.items[1]));
      final results = await Future.wait([first, second]);
      expect(results[0]!.identifier, equals('not_found'));
      expect(results[1]!.identifier, equals('not_found'));
    });

    test('a new pick is allowed after the previous one completes', () async {
      final selector = _Selector();
      final fixture = _twoOptions();
      final view = _FakeView(
        (f) async => FixtureChoice(document: f.items.first),
      );

      await selector.select(fixture, view, DataSelectorType.pick);
      await selector.select(fixture, view, DataSelectorType.pick);
      expect(view.pickCount, equals(2));
    });

    test('Default selector returns the document marked as default', () async {
      final selector = _Selector();
      final selected = await selector.select(
          _twoOptions(), null, DataSelectorType.defaultValue);
      expect(selected!.identifier, equals('ok'));
    });

    test('Default selector throws when nothing is marked default', () async {
      final selector = _Selector();
      final fixture = FixtureCollection(
        description: 'No default',
        items: [
          FixtureDocument(
              identifier: 'a',
              description: '200',
              defaultOption: false,
              data: {}),
          FixtureDocument(
              identifier: 'b',
              description: '400',
              defaultOption: false,
              data: {}),
        ],
      );

      expect(
        () => selector.select(fixture, null, DataSelectorType.defaultValue),
        throwsA(isA<StateError>()),
      );
    });
  });
}
