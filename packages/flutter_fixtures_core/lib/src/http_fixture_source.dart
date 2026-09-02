import 'fixture_collection.dart';
import 'fixture_source.dart';
import 'fixture_sources.dart';

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

  /// The canonical string rendering of this request's identity:
  /// `path?key=value&key=value`, pairs sorted by key then value, both
  /// escaped.
  ///
  /// One request always produces one target, whichever HTTP client built
  /// it and however that client ordered its query parameters — so recorded
  /// sessions match across adapters. Escaping keeps distinct requests
  /// distinct (`?a=1&a=2` never collides with `?a=1%2C2`).
  String get canonicalTarget {
    final pairs = <String>[];
    for (final entry in queryParameters.entries) {
      final values = entry.value is List ? entry.value as List : [entry.value];
      for (final value in values) {
        pairs.add('${Uri.encodeQueryComponent(entry.key)}='
            '${Uri.encodeQueryComponent('${value ?? ''}')}');
      }
    }
    pairs.sort();
    return pairs.isEmpty ? path : '$path?${pairs.join('&')}';
  }
}

/// The HTTP-typed [FixtureSource]: `resolve` takes an [HttpFixtureRequest]
/// and returns a [FixtureCollection], or `null` when the source has none.
///
/// Built-ins: `HttpFileFixtureSource` (fixture files) and
/// `OpenApiFixtureSource` (fixtures derived from an OpenAPI document);
/// `HttpFixtureSources` composes several in precedence order.
typedef HttpFixtureSource = FixtureSource<HttpFixtureRequest>;

/// The ordered composite of HTTP sources — see [FixtureSources].
typedef HttpFixtureSources = FixtureSources<HttpFixtureRequest>;
