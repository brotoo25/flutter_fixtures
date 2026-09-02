import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'fixture_source.dart';

/// An ordered composite of [FixtureSource]s — itself a source.
///
/// Sources are consulted in order and the first that resolves wins; that
/// same source then provides the selected document's payload. Use it to
/// layer fixture files over derived fixtures, for example:
///
/// ```dart
/// final sources = FixtureSources([
///   HttpFileFixtureSource(),
///   OpenApiFixtureSource(specPath: 'assets/fixtures/openapi.json'),
/// ]);
/// ```
///
/// Documents are routed back to their resolving source by identity, so a
/// source must hand out its own document instances (caching its own
/// collections across resolves is fine); a document instance shared by two
/// sources is rejected loudly rather than silently receiving the wrong
/// payload.
class FixtureSources<TRequest> implements FixtureSource<TRequest> {
  /// The sources, in precedence order.
  final List<FixtureSource<TRequest>> sources;

  // Which source resolved each document, so data() asks the right one.
  final Expando<FixtureSource<TRequest>> _resolvedBy = Expando('resolvedBy');

  FixtureSources(this.sources);

  @override
  Future<FixtureCollection?> resolve(TRequest request) async {
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
