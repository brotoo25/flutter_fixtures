import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_test/flutter_test.dart';

class LegacyDataQuery implements DataQuery<String, Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>?> find(String input) async {
    return {'description': input, 'values': []};
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    return FixtureCollection(
      description: source['description'] as String? ?? '',
      items: [],
    );
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    return {'identifier': document.identifier};
  }

  @override
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector, {
    DataSelectorDelay delay = DataSelectorDelay.instant,
  }) async {
    return fixture.items.isEmpty ? null : fixture.items.first;
  }
}

void main() {
  group('DataQuery backwards compatibility', () {
    test('supports legacy two generic parameters', () {
      final query = LegacyDataQuery();

      expect(
        query,
        isA<DataQuery<String, Map<String, dynamic>>>(),
      );
    });

    test('data remains typed as output', () async {
      final query = LegacyDataQuery();
      final result = await query.data(
        FixtureDocument(
          identifier: 'legacy',
          description: '200 OK',
          defaultOption: false,
        ),
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result!['identifier'], 'legacy');
    });
  });
}
