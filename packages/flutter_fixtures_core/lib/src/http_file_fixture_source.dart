import 'fixture_source.dart';
import 'http_fixture_source.dart';

/// The file-backed HTTP fixture source: core's [FixtureFileSource] with the
/// HTTP file naming convention.
///
/// This class owns exactly one thing — how an HTTP request maps to fixture
/// file names ([candidateNames]); file IO belongs to [FixtureFileSource].
/// Candidates, most specific first:
///
/// 1. `{METHOD}_{path}.json` — exact path, query ignored
///    (`GET_users.json`);
/// 2. `{METHOD}_{path}_{values}.json` — query values appended, sorted by
///    key (`GET_search_2_test.json` for `?q=test&page=2`);
/// 3. `{METHOD}_{path}_*_*.json` — one wildcard per query value;
/// 4. `{METHOD}_{path}_{{key}}_{{key}}.json` — mustache placeholders named
///    by the sorted query keys.
class HttpFileFixtureSource extends FixtureFileSource<HttpFixtureRequest> {
  HttpFileFixtureSource({
    super.mockFolder = 'assets/fixtures',
    super.assetLoader,
  }) : super(candidates: candidateNames);

  /// The HTTP fixture-file naming convention, as an ordered candidate list.
  static List<String> candidateNames(HttpFixtureRequest request) {
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
