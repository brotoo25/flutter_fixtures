import 'fixture_collection.dart';
import 'fixture_document.dart';

/// The HTTP request shape fixture sources resolve against.
///
/// Adapters map their client's request type (e.g. Dio's `RequestOptions`)
/// to this, so sources stay independent of any HTTP client.
///
/// [fromUri] is the canonical constructor: it owns request normalization
/// (scheme and host dropped, query merged out of the URL), so every source
/// sees the same shape and none needs to compensate. Sources may assume
/// [path] carries no scheme, host, or query string.
class HttpFixtureRequest {
  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;

  const HttpFixtureRequest({
    required this.method,
    required this.path,
    this.queryParameters = const {},
  });

  /// Builds the canonical request for a URI.
  ///
  /// The scheme and host are dropped — fixtures describe the request, not
  /// the environment it was sent to — and every query parameter in the URI
  /// (whether it arrived in the URL string or a query map the client merged
  /// in) lands in [queryParameters]; repeated keys keep all their values as
  /// a list. The method is uppercased.
  factory HttpFixtureRequest.fromUri(String method, Uri uri) {
    return HttpFixtureRequest(
      method: method.toUpperCase(),
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: {
        for (final entry in uri.queryParametersAll.entries)
          entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
      },
    );
  }
}

/// Seam for providing HTTP fixtures.
///
/// Implementations turn a request into a [FixtureCollection] — from fixture
/// files (`HttpFileFixtureSource`), an OpenAPI spec (`OpenApiFixtureSource`),
/// a Postman collection, or any custom format. HTTP adapters consult an
/// ordered list of sources; the first one that resolves wins.
abstract class HttpFixtureSource {
  /// Returns the fixture collection for [request], or `null` when this
  /// source has no fixture for it.
  Future<FixtureCollection?> resolve(HttpFixtureRequest request);

  /// Returns a document's payload, or `null` when this source cannot
  /// provide it.
  Future<Object?> data(FixtureDocument document);
}
