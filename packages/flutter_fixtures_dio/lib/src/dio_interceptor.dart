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
  final List<HttpFixtureSource> sources;

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
  }) : sources = sources ??
            [
              HttpFileFixtureSource(
                mockFolder: mockFolder,
                assetLoader: assetLoader,
              ),
            ];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final request = HttpFixtureRequest(
        method: options.method,
        path: options.path,
        queryParameters: options.queryParameters,
      );

      // The first source that resolves wins — and it alone provides the
      // payload, so a source can never answer for another's document.
      HttpFixtureSource? resolvedBy;
      FixtureCollection? fixtureCollection;
      for (final source in sources) {
        fixtureCollection = await source.resolve(request);
        if (fixtureCollection != null) {
          resolvedBy = source;
          break;
        }
      }
      if (fixtureCollection == null || resolvedBy == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No fixture found for request.',
          ),
        );
      }

      if (fixtureCollection.items.isEmpty) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No fixture options found for request.',
          ),
        );
      }

      // Select a fixture document based on the selector type
      final selectedDocument = await select(
        fixtureCollection,
        dataSelectorView,
        dataSelector,
        delay: dataSelectorDelay,
      );

      // If no document was selected, reject the request
      if (selectedDocument == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No fixture selected for request.',
          ),
        );
      }

      // HTTP fixtures encode the response status in the document description.
      final statusCode = selectedDocument.statusCode;
      if (statusCode == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'Fixture description "${selectedDocument.description}" '
                'must start with a 3-digit HTTP status code.',
          ),
        );
      }

      // Get the data for the selected document from the resolving source
      final responseData = await resolvedBy.data(selectedDocument);

      // Create a response with the selected data
      final response = Response(
        requestOptions: options,
        data: responseData,
        statusCode: statusCode,
        headers: Headers(),
      );

      // Add file content to headers if available
      final filePath = selectedDocument.dataPath;
      if (filePath != null && filePath.isNotEmpty) {
        response.headers.set('x-fixture-file-path', filePath);
      }

      // Resolve the request with the mock response
      return handler.resolve(response);
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
