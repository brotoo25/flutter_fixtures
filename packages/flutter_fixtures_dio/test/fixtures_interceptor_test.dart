import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_dio/flutter_fixtures_dio.dart';

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

/// A source with a canned collection and payload.
class FakeSource implements HttpFixtureSource {
  FakeSource({this.collection, this.payload});

  final FixtureCollection? collection;
  final Object? payload;
  int dataCalls = 0;

  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    return collection;
  }

  @override
  Future<Object?> data(FixtureDocument document) async {
    dataCalls++;
    return payload;
  }
}

class ThrowingSource implements HttpFixtureSource {
  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) {
    throw StateError('broken source');
  }

  @override
  Future<Object?> data(FixtureDocument document) async => null;
}

class CancellingView implements DataSelectorView {
  @override
  Future<FixtureChoice?> pick(FixtureCollection fixture) async => null;
}

/// Records the interceptor's outcome instead of driving a real request.
class RecordingHandler extends RequestInterceptorHandler {
  Response? resolved;
  DioException? rejected;

  @override
  void resolve(
    Response response, [
    bool callFollowingResponseInterceptor = false,
  ]) {
    resolved = response;
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    rejected = error;
  }
}

FixtureDocument doc(
  String identifier,
  String description, {
  bool defaultOption = false,
  Object? data,
  String? dataPath,
}) {
  return FixtureDocument(
    identifier: identifier,
    description: description,
    defaultOption: defaultOption,
    data: data,
    dataPath: dataPath,
  );
}

Future<RecordingHandler> run(
  FixturesInterceptor interceptor, {
  String method = 'GET',
  String path = '/users',
  Map<String, dynamic> queryParameters = const {},
}) async {
  final handler = RecordingHandler();
  interceptor.onRequest(
    RequestOptions(
      path: path,
      method: method,
      queryParameters: queryParameters,
    ),
    handler,
  );
  for (var i = 0;
      i < 50 && handler.resolved == null && handler.rejected == null;
      i++) {
    await Future.delayed(Duration.zero);
  }
  return handler;
}

void main() {
  group('FixturesInterceptor', () {
    test('serves the resolved document as a response', () async {
      final interceptor = FixturesInterceptor(
        sources: [
          FakeSource(
            collection: FixtureCollection(
              description: 'Users',
              items: [
                doc('ok', '201 Created', defaultOption: true, data: {'id': 1}),
              ],
            ),
            payload: {'id': 1},
          ),
        ],
        dataSelector: DataSelectorType.defaultValue,
      );

      final handler = await run(interceptor, method: 'POST');

      expect(handler.rejected, isNull);
      expect(handler.resolved!.statusCode, equals(201));
      expect(handler.resolved!.data, equals({'id': 1}));
    });

    test('serves fixture files through the default file source', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/GET_users.json': '''
        {
          "description": "Users",
          "values": [
            {
              "identifier": "list",
              "description": "200 OK",
              "default": true,
              "data": [{"id": 1, "name": "Alice"}]
            }
          ]
        }
        ''',
      });
      final interceptor = FixturesInterceptor(
        assetLoader: loader,
        dataSelector: DataSelectorType.defaultValue,
      );

      final handler = await run(interceptor);

      expect(handler.resolved!.statusCode, equals(200));
      expect(handler.resolved!.data, isA<List>());
    });

    test('sets the x-fixture-file-path header for external payloads', () async {
      final loader = InMemoryAssetLoader({
        'assets/fixtures/GET_users.json': '''
        {
          "description": "Users",
          "values": [
            {
              "identifier": "list",
              "description": "200 OK",
              "default": true,
              "dataPath": "data/users.json"
            }
          ]
        }
        ''',
        'assets/fixtures/data/users.json': '[{"id": 1}]',
      });
      final interceptor = FixturesInterceptor(
        assetLoader: loader,
        dataSelector: DataSelectorType.defaultValue,
      );

      final handler = await run(interceptor);

      expect(
          handler.resolved!.data,
          equals([
            {'id': 1}
          ]));
      expect(
        handler.resolved!.headers.value('x-fixture-file-path'),
        equals('data/users.json'),
      );
    });

    group('source ordering', () {
      const spec = '''
      {
        "openapi": "3.0.0",
        "paths": {
          "/users/{id}": {
            "get": {
              "summary": "Get a user",
              "responses": {
                "200": {
                  "description": "Success",
                  "content": {
                    "application/json": {"example": {"id": 42}}
                  }
                }
              }
            }
          }
        }
      }
      ''';

      List<HttpFixtureSource> sourcesWith(InMemoryAssetLoader loader) => [
            HttpFileFixtureSource(assetLoader: loader),
            OpenApiFixtureSource(
              specPath: 'assets/fixtures/openapi.json',
              assetLoader: loader,
            ),
          ];

      test('falls back to the spec when no fixture file matches', () async {
        final loader = InMemoryAssetLoader({
          'assets/fixtures/openapi.json': spec,
        });
        final interceptor = FixturesInterceptor(
          sources: sourcesWith(loader),
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor, path: '/users/42');

        expect(handler.resolved!.statusCode, equals(200));
        expect(handler.resolved!.data, equals({'id': 42}));
      });

      test('a hand-written fixture file wins over the spec', () async {
        final loader = InMemoryAssetLoader({
          'assets/fixtures/GET_users_42.json': '''
          {
            "description": "Users",
            "values": [
              {
                "identifier": "handwritten",
                "description": "200 OK",
                "default": true,
                "data": {"source": "file"}
              }
            ]
          }
          ''',
          'assets/fixtures/openapi.json': spec,
        });
        final interceptor = FixturesInterceptor(
          sources: sourcesWith(loader),
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor, path: '/users/42');

        expect(handler.resolved!.data, equals({'source': 'file'}));
        expect(
          loader.requestedPaths,
          isNot(contains('assets/fixtures/openapi.json')),
        );
      });

      test('the resolving source provides the payload, not earlier sources',
          () async {
        // The first source has no collection for the request but would
        // happily answer data() for any document; the winner's payload must
        // be used even when it is null.
        final wrongSource = FakeSource(payload: {'from': 'wrong source'});
        final winningSource = FakeSource(
          collection: FixtureCollection(
            description: 'No content',
            items: [doc('empty', '204 No Content', defaultOption: true)],
          ),
          payload: null,
        );
        final interceptor = FixturesInterceptor(
          sources: [wrongSource, winningSource],
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor);

        expect(handler.resolved!.statusCode, equals(204));
        expect(handler.resolved!.data, isNull);
        expect(wrongSource.dataCalls, equals(0));
      });
    });

    group('error handling', () {
      test('rejects when no source resolves', () async {
        final interceptor = FixturesInterceptor(
          sources: [FakeSource()],
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor);

        expect(
          handler.rejected!.error,
          equals('No fixture found for request.'),
        );
      });

      test('rejects when the collection has no options', () async {
        final interceptor = FixturesInterceptor(
          sources: [
            FakeSource(
              collection: FixtureCollection(description: 'Empty', items: []),
            ),
          ],
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor);

        expect(
          handler.rejected!.error,
          equals('No fixture options found for request.'),
        );
      });

      test('rejects when the user cancels an interactive pick', () async {
        final interceptor = FixturesInterceptor(
          sources: [
            FakeSource(
              collection: FixtureCollection(
                description: 'Users',
                items: [
                  doc('a', '200 OK', defaultOption: true),
                  doc('b', '404 Not Found'),
                ],
              ),
            ),
          ],
          dataSelectorView: CancellingView(),
          dataSelector: DataSelectorType.pick,
        );

        final handler = await run(interceptor);

        expect(
          handler.rejected!.error,
          equals('No fixture selected for request.'),
        );
      });

      test('rejects when the description carries no status code', () async {
        final interceptor = FixturesInterceptor(
          sources: [
            FakeSource(
              collection: FixtureCollection(
                description: 'Users',
                items: [
                  doc('list', 'Returns list of all users', defaultOption: true),
                ],
              ),
            ),
          ],
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor);

        expect(
          handler.rejected!.error,
          contains('must start with a 3-digit HTTP status code'),
        );
      });

      test('rejects when a source throws', () async {
        final interceptor = FixturesInterceptor(
          sources: [ThrowingSource()],
          dataSelector: DataSelectorType.defaultValue,
        );

        final handler = await run(interceptor);

        expect(handler.rejected!.error, contains('Error processing fixture:'));
        expect(handler.rejected!.error, contains('broken source'));
      });
    });
  });
}
