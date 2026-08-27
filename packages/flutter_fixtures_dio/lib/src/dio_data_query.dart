import 'package:dio/dio.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Implementation of DataQuery for Dio HTTP client
///
/// This class maps a Dio request to fixture file candidates and delegates
/// loading to [FixtureSource].
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
class DioDataQuery
    with FixtureSelector
    implements DataQuery<RequestOptions, Object> {
  /// The folder where mock data is stored
  final String mockFolder;

  final FixtureSource _source;

  /// Creates a new DioDataQuery with the specified mock folder
  ///
  /// [assetLoader] substitutes how fixture files are read; it defaults to
  /// the root asset bundle.
  DioDataQuery({
    this.mockFolder = 'assets/fixtures',
    FixtureAssetLoader assetLoader = const BundleAssetLoader(),
  }) : _source =
            FixtureSource(mockFolder: mockFolder, assetLoader: assetLoader);

  /// Gets the mock folder path
  String get mockFolderPath => mockFolder;

  @override
  Future<Object?> find(RequestOptions input) {
    return _source.resolve(_candidateNames(input));
  }

  /// Builds the ordered fixture-file candidates for a request.
  List<String> _candidateNames(RequestOptions input) {
    // Base file name from method and path (slashes replaced by underscores)
    final base = '${input.method}${input.path.replaceAll('/', '_')}';

    // Prepare query parameter segments (deterministic order by key)
    final queryParams = input.queryParameters;
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

  @override
  Future<FixtureCollection?> parse(Object source) async {
    return FixtureCollection.fromJson(source as Map<String, dynamic>);
  }

  @override
  Future<Object?> data(FixtureDocument document) {
    return _source.data(document);
  }
}
