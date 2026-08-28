import 'fixture_asset_loader.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'fixture_source.dart';
import 'http_fixture_source.dart';

/// The [HttpFixtureSource] backed by fixture files.
///
/// Maps a request to fixture-file candidates and delegates loading to
/// [FixtureSource].
///
/// ## File Naming Convention
///
/// The base name is `{METHOD}{PATH}` with `/` replaced by `_`
/// (e.g. `GET_users.json` for `GET /users`). For requests with query
/// parameters, candidates are tried in this order (query values are ordered
/// by sorted key name, not URL order):
///
/// 1. Exact, ignoring query params: `GET_search.json`
/// 2. Values appended: `GET_search_2_foo.json`
/// 3. Literal `*` per value: `GET_search_*_*.json`
/// 4. `{{key}}` per sorted key: `GET_search_{{page}}_{{q}}.json`
///
/// The `*` and `{{key}}` forms are literal file names, not globs — they
/// match any values with the same arity.
class HttpFileFixtureSource implements HttpFixtureSource {
  /// The folder where fixture files are stored.
  final String mockFolder;

  final FixtureSource _source;

  /// [assetLoader] substitutes how fixture files are read; it defaults to
  /// the root asset bundle.
  HttpFileFixtureSource({
    this.mockFolder = 'assets/fixtures',
    FixtureAssetLoader assetLoader = const BundleAssetLoader(),
  }) : _source =
            FixtureSource(mockFolder: mockFolder, assetLoader: assetLoader);

  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    final json = await _source.resolve(_candidateNames(request));
    return json == null ? null : FixtureCollection.fromJson(json);
  }

  @override
  Future<Object?> data(FixtureDocument document) {
    return _source.data(document);
  }

  /// Builds the ordered fixture-file candidates for a request.
  List<String> _candidateNames(HttpFixtureRequest request) {
    // Base file name from method and path (slashes replaced by underscores)
    final base = '${request.method}${request.path.replaceAll('/', '_')}';

    // Prepare query parameter segments (deterministic order by key)
    final queryParams = request.queryParameters;
    final sortedKeys = queryParams.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    String normalizeSegment(dynamic value) {
      final str = value is List
          ? value.map((v) => (v ?? '').toString()).join('-')
          : (value ?? '').toString();
      return str.replaceAll('/', '_').replaceAll(' ', '_');
    }

    final valueSegments = [
      for (final k in sortedKeys) normalizeSegment(queryParams[k]),
    ].where((s) => s.isNotEmpty).toList();

    return [
      // 1) Exact (no query params)
      '$base.json',
      if (valueSegments.isNotEmpty) ...[
        // 2) Values appended (e.g., GET_search_foo_2.json)
        '${base}_${valueSegments.join('_')}.json',
        // 3) Wildcards for each query value (e.g., GET_search_*.json)
        '${base}_${List.filled(valueSegments.length, '*').join('_')}.json',
        // 4) Mustache named by key order (e.g., GET_search_{{page}}_{{q}}.json)
        if (sortedKeys.isNotEmpty)
          '${base}_${sortedKeys.map((k) => '{{$k}}').join('_')}.json',
      ],
    ];
  }
}
