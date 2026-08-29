import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// The Dio adapter for the record-and-replay seam ([TrafficRecorder]).
///
/// While the recorder is recording, this interceptor captures every response
/// (including non-2xx responses surfaced as errors) into the in-progress
/// session. While it is replaying, requests are answered from the active
/// session without touching the network. When the recorder is idle, traffic
/// passes through untouched — the rest of the app never notices the module
/// exists.
///
/// Add it before other interceptors that produce responses (such as
/// `FixturesInterceptor`), so replayed sessions win. The engine —
/// `FixtureRecorder` from `flutter_fixtures_recorder` — plugs in through
/// the seam:
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RecorderInterceptor(recorder: recorder));
/// ```
///
/// Recording captures network traffic only. A response produced by a later
/// interceptor via `handler.resolve` (as `FixturesInterceptor` does) never
/// reaches this interceptor's response stage — Dio unwinds a plain resolve
/// straight to the caller — so fixture-served responses are not recorded.
///
/// HTTP requests are described to the recorder with source `'http'`, the
/// method as operation, and the path with sorted query as target — the host
/// is intentionally dropped, so a session recorded against one environment
/// replays against another.
class RecorderInterceptor extends Interceptor {
  /// The [RecordedRequest.source] used for HTTP traffic.
  static const String source = 'http';

  /// The recorder this interceptor feeds and reads.
  final TrafficRecorder recorder;

  /// Policy for replay requests with no recorded response.
  final ReplayMissBehavior onReplayMiss;

  RecorderInterceptor({
    required this.recorder,
    this.onReplayMiss = ReplayMissBehavior.forward,
  });

  /// Describes a Dio request in the recorder's source-agnostic shape.
  ///
  /// Request identity is core's knowledge: `HttpFixtureRequest.fromUri`
  /// normalizes, `canonicalTarget` renders — no HTTP normalization lives
  /// in this package.
  static RecordedRequest describe(RequestOptions options) {
    final request = HttpFixtureRequest.fromUri(options.method, options.uri);
    return RecordedRequest(
      source: source,
      operation: request.method,
      target: request.canonicalTarget,
      payload: options.data,
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    switch (recorder.decide(() => describe(options), onMiss: onReplayMiss)) {
      case Replayed(:final interaction):
        handler.resolve(_toResponse(interaction, options));
      case RejectRequest(:final message):
        handler.reject(
          DioException(requestOptions: options, error: message),
        );
      case ForwardToSource():
        handler.next(options);
    }
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

  // The capture thunk runs only while recording, so idle traffic builds
  // no request description and copies no headers.
  void _capture(Response response) {
    recorder.record(
      () => RecordedInteraction(
        request: describe(response.requestOptions),
        response: {
          'statusCode': response.statusCode ?? 0,
          'headers': response.headers.map,
          'body': response.data,
        },
        recordedAt: DateTime.now(),
      ),
    );
  }

  Response _toResponse(RecordedInteraction recorded, RequestOptions options) {
    final captured = (recorded.response as Map?) ?? const {};
    final headers = <String, List<String>>{
      for (final entry in ((captured['headers'] as Map?) ?? const {}).entries)
        // Content-length was captured from the original encoding and may
        // not match the re-encoded body, so it is not replayed.
        if ((entry.key as String).toLowerCase() != 'content-length')
          entry.key as String: List<String>.from(entry.value as List),
    };
    return Response(
      requestOptions: options,
      statusCode: captured['statusCode'] as int? ?? 0,
      data: captured['body'],
      headers: Headers.fromMap(headers),
    );
  }
}
