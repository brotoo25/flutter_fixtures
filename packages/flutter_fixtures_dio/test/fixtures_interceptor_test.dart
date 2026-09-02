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

/// Picks the second option and asks for it to be remembered.
class _RememberingView implements DataSelectorView {
  _RememberingView(this.onPick);
  final void Function() onPick;

  @override
  Future<FixtureChoice?> pick(FixtureCollection fixture) async {
    onPick();
    return FixtureChoice(document: fixture.items[1], remember: true);
  }
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
    test('remembered choices survive across requests on one pipeline',
        () async {
      var picks = 0;
      final view = _RememberingView(() => picks++);
      final interceptor = FixturesInterceptor(
        pipeline: FixturePipeline(
          source: FakeSource(
            collection: FixtureCollection(
              description: 'Users',
              items: [
                doc('a', '200 OK', defaultOption: true, data: {'v': 'a'}),
                doc('b', '404 Not Found', data: {'v': 'b'}),
              ],
            ),
            payload: {'v': 'b'},
          ),
          selector: DataSelectorType.pick,
          view: view,
        ),
      );

      await run(interceptor);
      final second = await run(interceptor);

      expect(picks, 1);
      expect(second.resolved!.statusCode, 404);
    });

    test('serves the resolved document as a response', () async {
      final interceptor = FixturesInterceptor(
        pipeline: FixturePipeline(
          source: FakeSource(
            collection: FixtureCollection(
              description: 'Users',
              items: [
                doc('ok', '201 Created', defaultOption: true, data: {'id': 1}),
              ],
            ),
            payload: {'id': 1},
          ),
          selector: DataSelectorType.defaultValue,
        ),
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
        pipeline: FixturePipeline(
          source: HttpFileFixtureSource(assetLoader: loader),
          selector: DataSelectorType.defaultValue,
        ),
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
        pipeline: FixturePipeline(
          source: HttpFileFixtureSource(assetLoader: loader),
          selector: DataSelectorType.defaultValue,
        ),
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
      final origin = ResponseOrigin.of(handler.resolved!);
      expect(origin, isA<FixtureOrigin>());
      expect((origin as FixtureOrigin).document, 'list');
      expect(origin.filePath, 'data/users.json');
    });

    test('stamps the origin on inline-payload responses too', () async {
      final interceptor = FixturesInterceptor(
        pipeline: FixturePipeline(
          source: FakeSource(
            collection: FixtureCollection(
              description: 'Users',
              items: [doc('inline', '200 OK', defaultOption: true, data: {})],
            ),
            payload: {},
          ),
          selector: DataSelectorType.defaultValue,
        ),
      );

      final handler = await run(interceptor);

      final origin = ResponseOrigin.of(handler.resolved!);
      expect(origin, isA<FixtureOrigin>());
      expect((origin as FixtureOrigin).document, 'inline');
      expect(origin.filePath, isNull);
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
          pipeline: FixturePipeline(
            source: HttpFixtureSources(sourcesWith(loader)),
            selector: DataSelectorType.defaultValue,
          ),
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
          pipeline: FixturePipeline(
            source: HttpFixtureSources(sourcesWith(loader)),
            selector: DataSelectorType.defaultValue,
          ),
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
          pipeline: FixturePipeline(
            source: HttpFixtureSources([wrongSource, winningSource]),
            selector: DataSelectorType.defaultValue,
          ),
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
          pipeline: FixturePipeline(
            source: FakeSource(),
            selector: DataSelectorType.defaultValue,
          ),
        );

        final handler = await run(interceptor);

        expect(handler.rejected!.error, isA<FixtureNotFound>());
        expect(handler.rejected!.message, 'No fixture found for request.');
      });

      test('rejects when the collection has no options', () async {
        final interceptor = FixturesInterceptor(
          pipeline: FixturePipeline(
            source: FakeSource(
              collection: FixtureCollection(description: 'Empty', items: []),
            ),
            selector: DataSelectorType.defaultValue,
          ),
        );

        final handler = await run(interceptor);

        expect(handler.rejected!.error, isA<FixtureEmpty>());
      });

      test('rejects when the user cancels an interactive pick', () async {
        final interceptor = FixturesInterceptor(
          pipeline: FixturePipeline(
            source: FakeSource(
              collection: FixtureCollection(
                description: 'Users',
                items: [
                  doc('a', '200 OK', defaultOption: true),
                  doc('b', '404 Not Found'),
                ],
              ),
            ),
            selector: DataSelectorType.pick,
            view: CancellingView(),
          ),
        );

        final handler = await run(interceptor);

        expect(handler.rejected!.error, isA<FixtureCancelled>());
        expect(handler.rejected!.message, 'No fixture selected for request.');
      });

      test('rejects when the description carries no status code', () async {
        final interceptor = FixturesInterceptor(
          pipeline: FixturePipeline(
            source: FakeSource(
              collection: FixtureCollection(
                description: 'Users',
                items: [
                  doc('list', 'Returns list of all users', defaultOption: true),
                ],
              ),
            ),
            selector: DataSelectorType.defaultValue,
          ),
        );

        final handler = await run(interceptor);

        expect(
          handler.rejected!.error,
          contains('must start with a 3-digit HTTP status code'),
        );
      });

      test('rejects when a source throws', () async {
        final interceptor = FixturesInterceptor(
          pipeline: FixturePipeline(
            source: ThrowingSource(),
            selector: DataSelectorType.defaultValue,
          ),
        );

        final handler = await run(interceptor);

        expect(handler.rejected!.error, contains('Error processing fixture:'));
        expect(handler.rejected!.error, contains('broken source'));
      });
    });
  });
}
