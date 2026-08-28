import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

class InMemoryAssetLoader implements FixtureAssetLoader {
  InMemoryAssetLoader(this.files);

  final Map<String, String> files;
  int loadCount = 0;

  @override
  Future<String> load(String path) async {
    loadCount++;
    final content = files[path];
    if (content == null) {
      throw StateError('Asset not found: $path');
    }
    return content;
  }
}

HttpFixtureRequest req(String method, String path) {
  return HttpFixtureRequest(method: method, path: path);
}

OpenApiFixtureSource sourceFor(Map<String, dynamic> spec) {
  return OpenApiFixtureSource(
    specPath: 'assets/openapi.json',
    assetLoader: InMemoryAssetLoader({'assets/openapi.json': jsonEncode(spec)}),
  );
}

void main() {
  group('OpenApiFixtureSource.resolve', () {
    test('builds a collection from named examples, one document each',
        () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/users': {
            'get': {
              'summary': 'List users',
              'responses': {
                '200': {
                  'description': 'Success',
                  'content': {
                    'application/json': {
                      'examples': {
                        'many': {
                          'summary': 'Multiple users',
                          'value': [
                            {'id': 1}
                          ],
                        },
                        'empty': {'value': []},
                      },
                    },
                  },
                },
                '500': {
                  'description': 'Server error',
                  'content': {
                    'application/json': {
                      'example': {'error': 'boom'},
                    },
                  },
                },
              },
            },
          },
        },
      });

      final collection = (await source.resolve(req('GET', '/users')))!;

      expect(collection.description, equals('List users'));
      expect(collection.items, hasLength(3));

      final many = collection.items[0];
      expect(many.identifier, equals('Multiple users'));
      expect(many.description, equals('200 Success'));
      expect(many.statusCode, equals(200));
      expect(many.defaultOption, isTrue);
      expect(
        many.data,
        equals([
          {'id': 1}
        ]),
      );

      final empty = collection.items[1];
      expect(empty.identifier, equals('empty'));
      expect(empty.data, equals([]));
      expect(empty.defaultOption, isFalse);

      final error = collection.items[2];
      expect(error.identifier, equals('Server error'));
      expect(error.statusCode, equals(500));
      expect(error.data, equals({'error': 'boom'}));
    });

    test('matches templated paths and strips server base paths', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'servers': [
          {'url': 'https://api.example.com/v1'},
        ],
        'paths': {
          '/users/{id}': {
            'get': {
              'operationId': 'getUser',
              'responses': {
                '200': {
                  'description': 'A user',
                  'content': {
                    'application/json': {
                      'example': {'id': 42},
                    },
                  },
                },
              },
            },
          },
        },
      });

      for (final path in ['/users/42', '/v1/users/42', 'users/42?full=true']) {
        final result = await source.resolve(req('GET', path));
        expect(result, isNotNull, reason: 'expected a match for $path');
        expect(result!.description, equals('getUser'));
      }
      expect(await source.resolve(req('GET', '/users')), isNull);
      expect(await source.resolve(req('DELETE', '/users/42')), isNull);
    });

    test('prefers concrete paths over templated ones, in any spec order',
        () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/users/{id}': {
            'get': {
              'operationId': 'getUser',
              'responses': {
                '200': {'description': 'OK'},
              },
            },
          },
          '/users/me': {
            'get': {
              'operationId': 'getCurrentUser',
              'responses': {
                '200': {'description': 'OK'},
              },
            },
          },
        },
      });

      final me = await source.resolve(req('GET', '/users/me'));
      final other = await source.resolve(req('GET', '/users/42'));

      expect(me!.description, equals('getCurrentUser'));
      expect(other!.description, equals('getUser'));
    });

    test('matches absolute request URLs by their path', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/users': {
            'get': {
              'operationId': 'listUsers',
              'responses': {
                '200': {'description': 'OK'},
              },
            },
          },
        },
      });

      // Normalization of absolute URLs is owned by HttpFixtureRequest.fromUri;
      // the source only sees the canonical path.
      final result = await source.resolve(HttpFixtureRequest.fromUri(
          'GET', Uri.parse('https://api.example.com/users')));

      expect(result!.description, equals('listUsers'));
    });

    test('generates sample data from schemas, resolving refs', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/orders': {
            'post': {
              'responses': {
                '201': {
                  'description': 'Created',
                  'content': {
                    'application/json': {
                      'schema': {r'$ref': '#/components/schemas/Order'},
                    },
                  },
                },
              },
            },
          },
        },
        'components': {
          'schemas': {
            'Order': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer', 'example': 7},
                'status': {
                  'type': 'string',
                  'enum': ['pending', 'shipped'],
                },
                'createdAt': {'type': 'string', 'format': 'date-time'},
                'total': {'type': 'number'},
                'paid': {'type': 'boolean'},
                'items': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string'},
                    },
                  },
                },
              },
            },
          },
        },
      });

      final collection = (await source.resolve(req('POST', '/orders')))!;
      final document = collection.items.single;

      expect(collection.description, equals('POST /orders'));
      expect(document.identifier, equals('Created'));
      expect(document.statusCode, equals(201));
      expect(
        document.data,
        equals({
          'id': 7,
          'status': 'pending',
          'createdAt': '2024-01-01T12:00:00Z',
          'total': 0,
          'paid': true,
          'items': [
            {'name': 'string'}
          ],
        }),
      );
    });

    test('merges allOf and survives \$ref cycles', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/nodes': {
            'get': {
              'responses': {
                '200': {
                  'description': 'A node',
                  'content': {
                    'application/json': {
                      'schema': {
                        'allOf': [
                          {r'$ref': '#/components/schemas/Base'},
                          {
                            'type': 'object',
                            'properties': {
                              'name': {'type': 'string'},
                            },
                          },
                        ],
                      },
                    },
                  },
                },
              },
            },
          },
        },
        'components': {
          'schemas': {
            'Base': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'parent': {r'$ref': '#/components/schemas/Base'},
              },
            },
          },
        },
      });

      final result = await source.resolve(req('GET', '/nodes'));
      final data = result!.items.single.data;

      expect(data, equals({'id': 0, 'parent': null, 'name': 'string'}));
    });

    test('maps status ranges and default, and marks the first 2xx as default',
        () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/health': {
            'get': {
              'responses': {
                '4XX': {'description': 'Client error'},
                '2XX': {'description': 'Alive'},
                'default': {'description': 'Unexpected error'},
              },
            },
          },
        },
      });

      final collection = (await source.resolve(req('GET', '/health')))!;

      expect(collection.items, hasLength(3));
      expect(collection.items[0].description, equals('400 Client error'));
      expect(collection.items[0].defaultOption, isFalse);
      expect(collection.items[1].description, equals('200 Alive'));
      expect(collection.items[1].defaultOption, isTrue);
      expect(collection.items[2].description, equals('500 Unexpected error'));
      // Responses without content still parse as documents with no payload.
      expect(collection.items[1].data, isNull);
      expect(collection.items[1].dataPath, isNull);
    });

    test('keeps identifiers unique across duplicate descriptions', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/things': {
            'get': {
              'responses': {
                '500': {'description': 'Error'},
                'default': {'description': 'Error'},
              },
            },
          },
        },
      });

      final collection = (await source.resolve(req('GET', '/things')))!;

      expect(
        collection.items.map((d) => d.identifier),
        equals(['Error', 'Error (2)']),
      );
    });

    test('returns null for operations the spec does not describe', () async {
      final source = sourceFor({
        'openapi': '3.0.0',
        'paths': {
          '/users': {
            'get': {
              'responses': {
                '200': {'description': 'OK'},
              },
            },
          },
        },
      });

      expect(await source.resolve(req('POST', '/users')), isNull);
      expect(await source.resolve(req('GET', '/missing')), isNull);
    });

    test('caches the spec across resolves', () async {
      final loader = InMemoryAssetLoader({
        'assets/openapi.json': jsonEncode({
          'openapi': '3.0.0',
          'paths': {
            '/a': {
              'get': {
                'responses': {
                  '200': {'description': 'OK'},
                },
              },
            },
          },
        }),
      });
      final source = OpenApiFixtureSource(
        specPath: 'assets/openapi.json',
        assetLoader: loader,
      );

      await source.resolve(req('GET', '/a'));
      await source.resolve(req('GET', '/a'));

      expect(loader.loadCount, equals(1));
    });

    test('a missing spec fails loudly', () async {
      final source = OpenApiFixtureSource(
        specPath: 'assets/openapi.json',
        assetLoader: InMemoryAssetLoader({}),
      );

      expect(
        () => source.resolve(req('GET', '/users')),
        throwsA(isA<StateError>()),
      );
    });

    test('malformed spec JSON fails loudly', () async {
      final source = OpenApiFixtureSource(
        specPath: 'assets/openapi.json',
        assetLoader: InMemoryAssetLoader({'assets/openapi.json': '{not json'}),
      );

      expect(
        () => source.resolve(req('GET', '/users')),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
