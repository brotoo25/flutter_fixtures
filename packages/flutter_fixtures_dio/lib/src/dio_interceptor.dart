import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Dio interceptor that provides mock responses using fixtures
///
/// This interceptor intercepts Dio HTTP requests and returns mock responses
/// based on fixture data.
class FixturesInterceptor extends Interceptor {
  /// The data query used to find fixture data
  final DataQuery<RequestOptions, Map<String, dynamic>> dataQuery;

  /// The view used for user selection of fixtures
  final DataSelectorView? dataSelectorView;

  /// The strategy for selecting fixtures
  final DataSelectorType dataSelector;

  /// The delay to apply when selecting fixtures
  ///
  /// Defaults to [DataSelectorDelay.instant] (no delay).
  /// Can be used to simulate network latency for testing loading states.
  final DataSelectorDelay dataSelectorDelay;

  /// Creates a new FixturesInterceptor with the specified components
  FixturesInterceptor({
    required this.dataQuery,
    this.dataSelectorView,
    required this.dataSelector,
    this.dataSelectorDelay = DataSelectorDelay.instant,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Find fixture data for the request
      final fixtureData = await dataQuery.find(options);
      if (fixtureData == null) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No fixture found for request.',
          ),
        );
      }

      // Parse the fixture data into a collection
      final fixtureCollection = await dataQuery.parse(fixtureData);

      // If the collection is null or empty, reject the request
      if (fixtureCollection == null || fixtureCollection.items.isEmpty) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: 'No fixture options found for request.',
          ),
        );
      }

      // Select a fixture document based on the selector type
      final selectedDocument = await dataQuery.select(
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

      // Get the data for the selected document
      final responseData = await dataQuery.data(selectedDocument);

      // Create a response with the selected data
      final response = Response(
        requestOptions: options,
        data: responseData,
        statusCode: int.parse(selectedDocument.description.substring(0, 3)),
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
