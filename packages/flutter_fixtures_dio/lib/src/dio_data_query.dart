import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Implementation of DataQuery for Dio HTTP client
///
/// Maps a Dio request to an [HttpFixtureRequest] and consults [sources] in
/// order; the first source that resolves wins. By default requests are
/// served from fixture files (see [HttpFileFixtureSource] for the file
/// naming convention). Add an [OpenApiFixtureSource] (or any custom
/// [HttpFixtureSource]) to derive fixtures for requests no earlier source
/// covers.
class DioDataQuery
    with FixtureSelector
    implements DataQuery<RequestOptions, Object> {
  /// The fixture sources consulted for each request, in order.
  final List<HttpFixtureSource> sources;

  /// Creates a new DioDataQuery.
  ///
  /// [mockFolder] and [assetLoader] configure the default
  /// [HttpFileFixtureSource] and are ignored when [sources] is given.
  DioDataQuery({
    String mockFolder = 'assets/fixtures',
    FixtureAssetLoader assetLoader = const BundleAssetLoader(),
    List<HttpFixtureSource>? sources,
  }) : sources = sources ??
            [
              HttpFileFixtureSource(
                mockFolder: mockFolder,
                assetLoader: assetLoader,
              ),
            ];

  @override
  Future<Object?> find(RequestOptions input) async {
    final request = HttpFixtureRequest(
      method: input.method,
      path: input.path,
      queryParameters: input.queryParameters,
    );
    for (final source in sources) {
      final result = await source.resolve(request);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  Future<FixtureCollection?> parse(Object source) async {
    // Sources already resolve to the model; nothing left to parse.
    return source as FixtureCollection;
  }

  @override
  Future<Object?> data(FixtureDocument document) async {
    for (final source in sources) {
      final result = await source.data(document);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
