import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

class _Selector with FixtureSelector {}

void main() {
  group('FixtureSelector memory behavior', () {
    setUp(() => FixtureSelectionMemory.clearAll());

    test('returns remembered document when selector is Pick', () async {
      final selector = _Selector();
      final fixture = FixtureCollection(
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

      // Remember the second option
      FixtureSelectionMemory.remember(fixture, fixture.items[1]);

      final selected =
          await selector.select(fixture, null, DataSelectorType.pick());
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
          await selector.select(single, null, DataSelectorType.pick());
      final defSel =
          await selector.select(single, null, DataSelectorType.defaultValue());
      final rndSel =
          await selector.select(single, null, DataSelectorType.random());

      expect(pickSel!.identifier, equals('only'));
      expect(defSel!.identifier, equals('only'));
      expect(rndSel!.identifier, equals('only'));
    });
  });
}
