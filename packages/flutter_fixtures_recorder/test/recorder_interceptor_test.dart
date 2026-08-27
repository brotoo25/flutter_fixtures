import 'package:dio/dio.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled handler fakes: they capture the outcome instead of driving
/// Dio's internal completer machinery.
class FakeRequestHandler extends RequestInterceptorHandler {
  Response? resolved;
  DioException? rejected;
  RequestOptions? forwarded;

  @override
  void resolve(Response response,
      [bool callFollowingResponseInterceptor = false]) {
    resolved = response;
  }

  @override
  void reject(DioException error,
      [bool callFollowingErrorInterceptor = false]) {
    rejected = error;
  }

  @override
  void next(RequestOptions requestOptions) {
    forwarded = requestOptions;
  }
}

class FakeResponseHandler extends ResponseInterceptorHandler {
  Response? forwarded;

  @override
  void next(Response response) {
    forwarded = response;
  }
}

class FakeErrorHandler extends ErrorInterceptorHandler {
  DioException? forwarded;

  @override
  void next(DioException err) {
    forwarded = err;
  }
}

Response responseFor(
  RequestOptions options, {
  int statusCode = 200,
  Object? data,
}) {
  return Response(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap({
      'content-type': ['application/json'],
      'content-length': ['42'],
    }),
  );
}

void main() {
  late FixtureRecorder recorder;
  late RecorderInterceptor interceptor;

  setUp(() {
    recorder = FixtureRecorder(store: MemoryRecordingSessionStore());
    interceptor = RecorderInterceptor(recorder: recorder);
  });

  Future<RecordingSession> recordOneInteraction() async {
    recorder.startRecording();
    final options = RequestOptions(path: 'https://api.test/users');
    interceptor.onResponse(
      responseFor(options, data: {'users': []}),
      FakeResponseHandler(),
    );
    return (await recorder.stopRecording())!;
  }

  group('while idle', () {
    test('requests, responses and errors pass through untouched', () {
      final options = RequestOptions(path: 'https://api.test/users');
      final requestHandler = FakeRequestHandler();
      interceptor.onRequest(options, requestHandler);
      expect(requestHandler.forwarded, options);
      expect(requestHandler.resolved, isNull);

      final responseHandler = FakeResponseHandler();
      interceptor.onResponse(responseFor(options), responseHandler);
      expect(responseHandler.forwarded, isNotNull);
      expect(recorder.recordedCount, 0);
    });
  });

  group('recording', () {
    test('captures responses with their request context', () async {
      recorder.startRecording();
      final options = RequestOptions(
        path: 'https://api.test/users',
        method: 'POST',
        data: {'name': 'Ada'},
      );
      interceptor.onResponse(
        responseFor(options, statusCode: 201, data: {'id': 1}),
        FakeResponseHandler(),
      );

      final session = (await recorder.stopRecording())!;
      final interaction = session.interactions.single;
      expect(interaction.method, 'POST');
      expect(interaction.uri, Uri.parse('https://api.test/users'));
      expect(interaction.requestBody, {'name': 'Ada'});
      expect(interaction.statusCode, 201);
      expect(interaction.responseBody, {'id': 1});
    });

    test('captures error-status responses surfaced through onError', () async {
      recorder.startRecording();
      final options = RequestOptions(path: 'https://api.test/users');
      final handler = FakeErrorHandler();
      final error = DioException(
        requestOptions: options,
        response: responseFor(options, statusCode: 404, data: 'not found'),
      );
      interceptor.onError(error, handler);

      expect(handler.forwarded, error);
      final session = (await recorder.stopRecording())!;
      expect(session.interactions.single.statusCode, 404);
    });

    test('ignores transport errors without a response', () {
      recorder.startRecording();
      final options = RequestOptions(path: 'https://api.test/users');
      interceptor.onError(
        DioException(requestOptions: options),
        FakeErrorHandler(),
      );
      expect(recorder.recordedCount, 0);
    });
  });

  group('replaying', () {
    test('answers recorded requests without hitting the network', () async {
      final session = await recordOneInteraction();
      await recorder.startReplay(session.id);

      final handler = FakeRequestHandler();
      interceptor.onRequest(
        RequestOptions(path: 'https://api.test/users'),
        handler,
      );

      expect(handler.resolved, isNotNull);
      expect(handler.resolved!.statusCode, 200);
      expect(handler.resolved!.data, {'users': []});
      expect(handler.forwarded, isNull);
    });

    test('does not replay the stale content-length header', () async {
      final session = await recordOneInteraction();
      await recorder.startReplay(session.id);

      final handler = FakeRequestHandler();
      interceptor.onRequest(
        RequestOptions(path: 'https://api.test/users'),
        handler,
      );

      expect(
          handler.resolved!.headers.value('content-type'), 'application/json');
      expect(handler.resolved!.headers.value('content-length'), isNull);
    });

    test('forwards unrecorded requests by default', () async {
      final session = await recordOneInteraction();
      await recorder.startReplay(session.id);

      final handler = FakeRequestHandler();
      interceptor.onRequest(
        RequestOptions(path: 'https://api.test/unknown'),
        handler,
      );
      expect(handler.forwarded, isNotNull);
      expect(handler.rejected, isNull);
    });

    test('rejects unrecorded requests when configured to', () async {
      interceptor = RecorderInterceptor(
        recorder: recorder,
        onReplayMiss: ReplayMissBehavior.reject,
      );
      final session = await recordOneInteraction();
      await recorder.startReplay(session.id);

      final handler = FakeRequestHandler();
      interceptor.onRequest(
        RequestOptions(path: 'https://api.test/unknown'),
        handler,
      );
      expect(handler.rejected, isNotNull);
      expect(handler.forwarded, isNull);
    });
  });
}
