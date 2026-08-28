import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'http_fixture_source.dart';

/// An ordered composite of HTTP fixture sources — itself an
/// [HttpFixtureSource].
///
/// Owns the precedence rule the glossary states for HTTP Fixture Sources:
/// sources are consulted in order, the first one that resolves wins, and
/// that same source alone provides the selected document's payload — a
/// source can never answer for another's document.
///
/// Adapters compose it like any single source:
///
/// ```dart
/// final sources = HttpFixtureSources([
///   HttpFileFixtureSource(),
///   OpenApiFixtureSource(specPath: 'assets/fixtures/openapi.json'),
/// ]);
/// // find: () => sources.resolve(request), data: sources.data
/// ```
///
/// Payload routing is per document identity, so each source must hand out
/// its own document instances (reusing them across its own resolves is
/// fine — the built-in sources build fresh ones per resolve). A document
/// instance that arrives through two different sources is ambiguous, and
/// [resolve] fails loudly instead of silently rerouting an in-flight
/// request's payload.
class HttpFixtureSources implements HttpFixtureSource {
  /// The sources consulted for each request, in precedence order.
  final List<HttpFixtureSource> sources;

  /// Which source resolved each document, keyed by document identity, so
  /// concurrent requests can never cross wires.
  final Expando<HttpFixtureSource> _resolvedBy = Expando('resolvedBy');

  HttpFixtureSources(this.sources);

  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    for (final source in sources) {
      final collection = await source.resolve(request);
      if (collection != null) {
        for (final document in collection.items) {
          final owner = _resolvedBy[document];
          if (owner != null && !identical(owner, source)) {
            throw StateError(
              'Document "${document.identifier}" was already resolved by '
              'another source. Sources must hand out their own document '
              'instances; a shared instance would silently receive the '
              'wrong payload.',
            );
          }
          _resolvedBy[document] = source;
        }
        return collection;
      }
    }
    return null;
  }

  @override
  Future<Object?> data(FixtureDocument document) {
    final source = _resolvedBy[document];
    if (source == null) {
      throw StateError(
        'Document "${document.identifier}" was not resolved by these '
        'sources; data() only serves documents returned by resolve().',
      );
    }
    return source.data(document);
  }
}
