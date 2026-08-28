import 'fixture_document.dart';

/// The HTTP request shape fixture sources resolve against.
///
/// Adapters map their client's request type (e.g. Dio's `RequestOptions`)
/// to this, so sources stay independent of any HTTP client.
class HttpFixtureRequest {
  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;

  const HttpFixtureRequest({
    required this.method,
    required this.path,
    this.queryParameters = const {},
  });
}

/// Seam for providing HTTP fixtures.
///
/// Implementations turn a request into a fixture collection — from fixture
/// files (`HttpFileFixtureSource`), an OpenAPI spec (`OpenApiFixtureSource`),
/// a Postman collection, or any custom format. HTTP adapters consult an
/// ordered list of sources; the first one that resolves wins.
abstract class HttpFixtureSource {
  /// Returns the fixture collection for [request], in the fixture wire
  /// format (`{"description": ..., "values": [...]}`), or `null` when this
  /// source has no fixture for it.
  Future<Map<String, dynamic>?> resolve(HttpFixtureRequest request);

  /// Returns a document's payload, or `null` when this source cannot
  /// provide it.
  Future<Object?> data(FixtureDocument document);
}
