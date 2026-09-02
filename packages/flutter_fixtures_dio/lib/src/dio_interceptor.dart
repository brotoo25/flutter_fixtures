import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Dio interceptor that serves fixture responses through a
/// [FixturePipeline].
///
/// Every request is normalized into an [HttpFixtureRequest] and served by
/// the pipeline — sources, selection strategy, picker, memory and delay all
/// live there. This interceptor only renders the outcome in Dio's terms: a
/// [FixtureServed] becomes a [Response] whose status comes from the
/// document's description, and a [FixtureMiss] rejects with a
/// [DioException] whose `error` is the miss itself, so callers can branch
/// on [FixtureNotFound], [FixtureEmpty], or [FixtureCancelled].
///
/// ```dart
/// final pipeline = FixturePipeline(
///   source: HttpFileFixtureSource(),
///   selector: DataSelectorType.pick,
///   view: FixturesDialogView.of(context),
/// );
/// dio.interceptors.add(FixturesInterceptor(pipeline: pipeline));
/// ```
///
/// Build the pipeline once, next to the Dio instance: remembered choices
/// live in it.
class FixturesInterceptor extends Interceptor {
  /// The pipeline every request is served through.
  final FixturePipeline<HttpFixtureRequest> pipeline;

  FixturesInterceptor({required this.pipeline});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // options.uri carries the merged query and resolves relative paths
      // against the base URL; fromUri owns the normalization from there.
      final request = HttpFixtureRequest.fromUri(options.method, options.uri);

      switch (await pipeline.serve(request)) {
        case FixtureMiss miss:
          return handler.reject(
            DioException(
              requestOptions: options,
              error: miss,
              message: miss.message,
            ),
          );
        case FixtureServed(:final document, :final payload):
          // HTTP fixtures encode the response status in the description.
          final statusCode = document.statusCode;
          if (statusCode == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Fixture description "${document.description}" '
                    'must start with a 3-digit HTTP status code.',
              ),
            );
          }

          final response = Response(
            requestOptions: options,
            data: payload,
            statusCode: statusCode,
            headers: Headers(),
          );

          // Add file content to headers if available
          final filePath = document.dataPath;
          if (filePath != null && filePath.isNotEmpty) {
            response.headers.set('x-fixture-file-path', filePath);
          }

          // Resolve through the response-interceptor stage, so interceptors
          // registered earlier (logging, RecorderInterceptor) observe the
          // fixture-served response like any other.
          return handler.resolve(response, true);
      }
    } catch (e) {
      // If anything goes wrong, reject the request with the error
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'Error processing fixture: $e',
        ),
      );
    }
  }
}
