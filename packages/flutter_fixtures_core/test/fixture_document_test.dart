import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

void main() {
  group('FixtureDocument', () {
    test('rejects a document declaring both data and dataPath', () {
      expect(
        () => FixtureDocument(
          identifier: 'both',
          description: '200 OK',
          defaultOption: false,
          data: {'a': 1},
          dataPath: 'data/a.json',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allows inline data only, dataPath only, or neither', () {
      FixtureDocument(
          identifier: 'inline',
          description: '200',
          defaultOption: false,
          data: {'a': 1});
      FixtureDocument(
          identifier: 'external',
          description: '200',
          defaultOption: false,
          dataPath: 'data/a.json');
      FixtureDocument(
          identifier: 'empty', description: '204', defaultOption: false);
    });

    group('statusCode', () {
      test('parses a leading 3-digit code', () {
        final doc = FixtureDocument(
            identifier: 'ok', description: '200 Success', defaultOption: true);
        expect(doc.statusCode, equals(200));
      });

      test('parses a bare code', () {
        final doc = FixtureDocument(
            identifier: 'ok', description: '404', defaultOption: false);
        expect(doc.statusCode, equals(404));
      });

      test('is null for prose descriptions', () {
        final doc = FixtureDocument(
            identifier: 'list',
            description: 'Returns list of all users',
            defaultOption: false);
        expect(doc.statusCode, isNull);
      });

      test('is null for short or non-code prefixes', () {
        expect(
          FixtureDocument(
                  identifier: 'a', description: '20', defaultOption: false)
              .statusCode,
          isNull,
        );
        expect(
          FixtureDocument(
                  identifier: 'b',
                  description: '2000s data',
                  defaultOption: false)
              .statusCode,
          isNull,
        );
      });
    });

    test('fromJson maps wire format fields', () {
      final doc = FixtureDocument.fromJson({
        'identifier': 'ok',
        'description': '200 OK',
        'default': true,
        'data': {'a': 1},
      });
      expect(doc.identifier, equals('ok'));
      expect(doc.defaultOption, isTrue);
      expect(doc.statusCode, equals(200));
    });
  });

  group('FixtureCollection.fromJson', () {
    test('parses description and values', () {
      final collection = FixtureCollection.fromJson({
        'description': 'Users API',
        'values': [
          {'identifier': 'ok', 'description': '200 OK', 'default': true},
          {'identifier': 'err', 'description': '500 Error'},
        ],
      });
      expect(collection.description, equals('Users API'));
      expect(collection.items, hasLength(2));
      expect(collection.items[1].defaultOption, isFalse);
    });

    test('a fixture declaring data and dataPath fails at parse time', () {
      expect(
        () => FixtureCollection.fromJson({
          'description': 'Bad',
          'values': [
            {
              'identifier': 'both',
              'description': '200',
              'data': {'a': 1},
              'dataPath': 'data/a.json',
            },
          ],
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
