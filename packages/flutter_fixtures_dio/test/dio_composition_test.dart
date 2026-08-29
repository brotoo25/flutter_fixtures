import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_dio/flutter_fixtures_dio.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// A network stand-in: every request that reaches the wire gets this JSON.
class _StubHttpAdapter implements HttpClientAdapter {
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits++;
    return ResponseBody.fromString(
      jsonEncode({'from': 'network'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An in-memory HTTP Fixture Source, so fixtures serve without assets.
class _FakeFixtureSource implements HttpFixtureSource {
  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    return FixtureCollection(
      description: 'Fixtures for ${request.path}',
      items: [
        FixtureDocument(
          identifier: 'ok',
          description: '200 OK',
          defaultOption: true,
          data: {'from': 'fixture'},
        ),
      ],
    );
  }

  @override
  Future<Object?> data(FixtureDocument document) async => document.data;
}

/// These tests run a real Dio with both interceptors installed — the
/// composition the READMEs describe — pinning Dio's actual chain semantics
/// instead of assuming them.
void main() {
  late FixtureRecorder recorder;
  late _StubHttpAdapter network;

  Dio buildDio({bool withFixtures = false}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    network = _StubHttpAdapter();
    dio.httpClientAdapter = network;
    dio.interceptors.add(RecorderInterceptor(recorder: recorder));
    if (withFixtures) {
      dio.interceptors.add(FixturesInterceptor(
        sources: [_FakeFixtureSource()],
        dataSelector: DataSelectorType.defaultValue,
      ));
    }
    return dio;
  }

  setUp(() {
    recorder = FixtureRecorder(store: MemoryRecordingSessionStore());
  });

  test('records network traffic and replays it without touching the wire',
      () async {
    final dio = buildDio();

    recorder.startRecording();
    await dio.get('/users');
    final session = (await recorder.stopRecording())!;
    expect(session.interactions, hasLength(1));
    expect(network.hits, 1);

    await recorder.startReplay(session.id);
    final replayed = await dio.get('/users');
    expect(replayed.data, {'from': 'network'});
    expect(network.hits, 1); // the wire was not touched again
  });

  test('replay wins over a following FixturesInterceptor', () async {
    final plain = buildDio();
    recorder.startRecording();
    await plain.get('/users');
    final session = (await recorder.stopRecording())!;

    final dio = buildDio(withFixtures: true);
    await recorder.startReplay(session.id);
    final response = await dio.get('/users');
    expect(response.data, {'from': 'network'}); // recorded, not fixture
  });

  test('while idle, fixtures serve and the recorder stays untouched', () async {
    final dio = buildDio(withFixtures: true);
    final response = await dio.get('/users');
    expect(response.data, {'from': 'fixture'});
    expect(recorder.recordedCount, 0);
    expect(network.hits, 0);
  });

  test('a session crosses JSON persistence and replays through a real Dio',
      () async {
    final dio = buildDio();

    recorder.startRecording();
    await dio.get('/users');
    final session = (await recorder.stopRecording())!;

    // A file-backed store hands back plain JSON, not the original Dart
    // objects — replay must survive the round-trip end to end.
    final restored = RecordingSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );
    recorder.startReplayOf(restored);

    final replayed = await dio.get('/users');
    expect(replayed.data, {'from': 'network'});
    expect(replayed.statusCode, 200);
    expect(network.hits, 1); // the wire was not touched again
  });

  test(
      'fixture-served responses ARE captured while recording — '
      'FixturesInterceptor resolves through the response chain', () async {
    final dio = buildDio(withFixtures: true);

    recorder.startRecording();
    final response = await dio.get('/users');
    expect(response.data, {'from': 'fixture'});
    expect(network.hits, 0);

    expect(recorder.recordedCount, 1);
    final session = (await recorder.stopRecording())!;
    final captured = session.interactions.single.response as Map;
    expect(captured['body'], {'from': 'fixture'});

    // Replay the fixture-chosen session: same response, no fixture
    // pipeline involved, network still untouched.
    await recorder.startReplay(session.id);
    final replayed = await dio.get('/users');
    expect(replayed.data, {'from': 'fixture'});
    expect(network.hits, 0);
  });
}
