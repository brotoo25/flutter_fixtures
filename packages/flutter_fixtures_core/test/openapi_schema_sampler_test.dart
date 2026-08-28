import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/src/openapi_schema_sampler.dart';

void main() {
  OpenApiSchemaSampler sampler([Map<String, dynamic> spec = const {}]) {
    return OpenApiSchemaSampler(spec);
  }

  group('OpenApiSchemaSampler.sample', () {
    test('explicit example-like values win, in precedence order', () {
      final s = sampler();
      expect(s.sample({'type': 'integer', 'example': 7}), equals(7));
      expect(
        s.sample({
          'examples': [1, 2]
        }),
        equals(1),
      );
      expect(s.sample({'const': 'fixed'}), equals('fixed'));
      expect(s.sample({'default': 'fallback'}), equals('fallback'));
      expect(
        s.sample({
          'enum': ['pending', 'shipped']
        }),
        equals('pending'),
      );
    });

    test('generates typed placeholders', () {
      final s = sampler();
      expect(s.sample({'type': 'integer'}), equals(0));
      expect(s.sample({'type': 'number'}), equals(0));
      expect(s.sample({'type': 'boolean'}), equals(true));
      expect(s.sample({'type': 'string'}), equals('string'));
    });

    test('honours string formats', () {
      final s = sampler();
      expect(s.sample({'type': 'string', 'format': 'uuid'}),
          equals('00000000-0000-4000-8000-000000000000'));
      expect(s.sample({'type': 'string', 'format': 'date-time'}),
          equals('2024-01-01T12:00:00Z'));
      expect(s.sample({'type': 'string', 'format': 'email'}),
          equals('user@example.com'));
      expect(
          s.sample({'type': 'string', 'format': 'unknown'}), equals('string'));
    });

    test('samples objects property by property', () {
      expect(
        sampler().sample({
          'type': 'object',
          'properties': {
            'id': {'type': 'integer'},
            'name': {'type': 'string'},
          },
        }),
        equals({'id': 0, 'name': 'string'}),
      );
    });

    test('samples arrays as a single-item list, or empty without items', () {
      final s = sampler();
      expect(
        s.sample({
          'type': 'array',
          'items': {'type': 'integer'}
        }),
        equals([0]),
      );
      expect(s.sample({'type': 'array'}), equals([]));
    });

    test('infers object and array types from their shape', () {
      final s = sampler();
      expect(
        s.sample({
          'properties': {
            'id': {'type': 'integer'}
          }
        }),
        equals({'id': 0}),
      );
      expect(
        s.sample({
          'items': {'type': 'boolean'}
        }),
        equals([true]),
      );
    });

    test('picks the first non-null type from an OpenAPI 3.1 type array', () {
      expect(
        sampler().sample({
          'type': ['null', 'string']
        }),
        equals('string'),
      );
    });

    test('resolves \$refs against the spec', () {
      final s = sampler({
        'components': {
          'schemas': {
            'Id': {'type': 'integer', 'example': 42},
          },
        },
      });

      expect(s.sample({r'$ref': '#/components/schemas/Id'}), equals(42));
    });

    test('merges allOf across refs', () {
      final s = sampler({
        'components': {
          'schemas': {
            'Base': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'}
              },
            },
          },
        },
      });

      expect(
        s.sample({
          'allOf': [
            {r'$ref': '#/components/schemas/Base'},
            {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'}
              },
            },
          ],
        }),
        equals({'id': 0, 'name': 'string'}),
      );
    });

    test('takes the first variant of oneOf/anyOf that samples', () {
      final s = sampler();
      expect(
        s.sample({
          'oneOf': [
            {'type': 'unknown'},
            {'type': 'integer'},
          ],
        }),
        equals(0),
      );
      expect(
        s.sample({
          'anyOf': [
            {'type': 'string'},
          ],
        }),
        equals('string'),
      );
    });

    test('a \$ref cycle yields null', () {
      final s = sampler({
        'components': {
          'schemas': {
            'Node': {
              'type': 'object',
              'properties': {
                'parent': {r'$ref': '#/components/schemas/Node'},
              },
            },
          },
        },
      });

      expect(
        s.sample({r'$ref': '#/components/schemas/Node'}),
        equals({'parent': null}),
      );
    });

    test('returns null for non-schema nodes and unresolvable refs', () {
      final s = sampler();
      expect(s.sample(null), isNull);
      expect(s.sample('not a schema'), isNull);
      expect(s.sample({r'$ref': '#/missing'}), isNull);
      expect(s.sample({r'$ref': 'external.json#/x'}), isNull);
    });
  });

  group('OpenApiSchemaSampler.resolvePointer', () {
    test('walks maps and lists, unescaping ~0 and ~1', () {
      final s = sampler({
        'a/b': {
          'items': ['first', 'second'],
        },
        '~tilde': true,
      });

      expect(s.resolvePointer('#/a~1b/items/1'), equals('second'));
      expect(s.resolvePointer('#/~0tilde'), equals(true));
      expect(s.resolvePointer('#/a~1b/items/9'), isNull);
      expect(s.resolvePointer('not-a-pointer'), isNull);
    });
  });
}
