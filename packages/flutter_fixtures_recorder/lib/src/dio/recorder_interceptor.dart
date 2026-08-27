import 'package:dio/dio.dart';

import '../fixture_recorder.dart';
import '../recorded_interaction.dart';

/// What to do with a request that has no recorded response during replay.
enum ReplayMissBehavior {
  /// Let the request continue to the network (the default). Online, the app
  /// keeps working; offline, the request fails the way it naturally would.
  forward,

  /// Reject the request with a [DioException]. Use this to guarantee a demo
  /// never touches the network.
  reject,
}

/// The Dio adapter for the recorder module.
///
/// While the recorder is recording, this interceptor captures every response
/// (including non-2xx responses surfaced as errors) into the in-progress
/// session. While it is replaying, requests are answered from the active
/// session without touching the network. When the recorder is idle, traffic
/// passes through untouched — the rest of the app never notices the module
/// exists.
///
/// Add it before other interceptors that produce responses (such as
/// `FixturesInterceptor`), so replayed sessions win and recording sees the
/// final response:
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RecorderInterceptor(recorder: recorder));
/// ```
class RecorderInterceptor extends Interceptor {
  /// The recorder this interceptor feeds and reads.
  final FixtureRecorder recorder;

  /// Policy for replay requests with no recorded response.
  final ReplayMissBehavior onReplayMiss;

  RecorderInterceptor({
    required this.recorder,
    this.onReplayMiss = ReplayMissBehavior.forward,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final recorded = recorder.replayResponseFor(options.method, options.uri);
    if (recorded != null) {
      // Content-length was captured from the original encoding and may not
      // match the re-encoded body, so it is not replayed.
      final headers = Map.of(recorded.responseHeaders)
        ..removeWhere((key, _) => key.toLowerCase() == 'content-length');
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: recorded.statusCode,
          data: recorded.responseBody,
          headers: Headers.fromMap(headers),
        ),
      );
    }
    if (recorder.isReplaying && onReplayMiss == ReplayMissBehavior.reject) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'No recorded response for '
              '"${options.method} ${options.uri}" in session '
              '"${recorder.replaySession?.name}".',
        ),
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _capture(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Error-status responses (4xx/5xx) arrive here, and they are part of
    // the traffic a session should reproduce. Transport failures without a
    // response are not captured.
    final response = err.response;
    if (response != null) _capture(response);
    handler.next(err);
  }

  void _capture(Response response) {
    if (!recorder.isRecording) return;
    final options = response.requestOptions;
    recorder.record(
      RecordedInteraction(
        method: options.method,
        uri: options.uri,
        requestBody: options.data,
        statusCode: response.statusCode ?? 0,
        responseHeaders: Map.of(response.headers.map),
        responseBody: response.data,
        recordedAt: DateTime.now(),
      ),
    );
  }
}
