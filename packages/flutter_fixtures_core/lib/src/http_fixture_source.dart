/// Seam for deriving HTTP fixtures from an API description.
///
/// Implementations turn an external document that already describes an API —
/// an OpenAPI spec (`OpenApiFixtureSource`), a Postman collection, or any
/// custom format — into fixture collections. HTTP adapters use one as a
/// fallback for requests with no hand-written fixture file.
abstract class HttpFixtureSource {
  /// Returns the fixture collection for [method] and [path], in the fixture
  /// wire format (`{"description": ..., "values": [...]}`), or `null` when
  /// this source describes no such operation.
  Future<Map<String, dynamic>?> resolve(String method, String path);
}
