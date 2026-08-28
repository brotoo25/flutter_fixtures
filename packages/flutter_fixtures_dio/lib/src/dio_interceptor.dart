import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Dio interceptor that provides mock responses using fixtures.
///
/// Maps each request to an [HttpFixtureRequest] and consults [sources] in
/// order; the first source that resolves wins, and that same source provides
/// the selected document's payload. By default requests are served from
/// fixture files (see [HttpFileFixtureSource] for the file naming
/// convention). Add an [OpenApiFixtureSource] (or any custom
/// [HttpFixtureSource]) to derive fixtures for requests no earlier source
/// covers.
class FixturesInterceptor extends Interceptor with FixtureSelector {
  /// The fixture sources consulted for each request, in order.
  final HttpFixtureSources sources;

  /// The view used for user selection of fixtures
  final DataSelectorView? dataSelectorView;

  /// The strategy for selecting fixtures
  final DataSelectorType dataSelector;

  /// The delay to apply when selecting fixtures
  ///
  /// Defaults to [DataSelectorDelay.instant] (no delay).
  /// Can be used to simulate network latency for testing loading states.
  final DataSelectorDelay dataSelectorDelay;

  /// Creates a new FixturesInterceptor.
  ///
  /// [mockFolder] and [assetLoader] configure the default
  /// [HttpFileFixtureSource] and are ignored when [sources] is given.
  FixturesInterceptor({
    List<HttpFixtureSource>? sources,
    String mockFolder = 'assets/fixtures',
    FixtureAssetLoader assetLoader = const BundleAssetLoader(),
    this.dataSelectorView,
    required this.dataSelector,
    this.dataSelectorDelay = DataSelectorDelay.instant,
  }) : sources = HttpFixtureSources(sources ??
            [
              HttpFileFixtureSource(
                mockFolder: mockFolder,
                assetLoader: assetLoader,
              ),
            ]);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // options.uri carries the merged query and resolves relative paths
      // against the base URL; fromUri owns the normalization from there.
      final request = HttpFixtureRequest.fromUri(options.method, options.uri);

      final outcome = await serve(
        find: () => sources.resolve(request),
        data: sources.data,
        view: dataSelectorView,
        selector: dataSelector,
        delay: dataSelectorDelay,
      );

      switch (outcome) {
        case FixtureNotFound():
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'No fixture found for request.',
            ),
          );
        case FixtureEmpty():
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'No fixture options found for request.',
            ),
          );
        case FixtureCancelled():
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'No fixture selected for request.',
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

          return handler.resolve(response);
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
