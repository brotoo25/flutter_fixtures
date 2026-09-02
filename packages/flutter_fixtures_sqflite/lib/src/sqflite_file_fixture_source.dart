import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'sqflite_query.dart';

/// The file-backed sqflite fixture source: core's [FixtureFileSource] with
/// the sqflite file naming convention ([SqfliteQuery.fixtureCandidates]).
///
/// Fixture files live under `assets/fixtures/database` by default and are
/// named after the operation and table — `query_users.json`,
/// `insert_orders.json` — with a where-clause variant tried first when the
/// statement has one. File IO (candidate lookup, JSON decoding, payload
/// loading) belongs to [FixtureFileSource].
class SqfliteFileFixtureSource extends FixtureFileSource<SqfliteQuery> {
  SqfliteFileFixtureSource({
    super.mockFolder = 'assets/fixtures/database',
    super.assetLoader,
  }) : super(candidates: candidateNames);

  /// The sqflite fixture-file naming convention, as an ordered candidate
  /// list.
  static List<String> candidateNames(SqfliteQuery query) =>
      query.fixtureCandidates;
}

/// Backwards-compatible alias for [SqfliteFileFixtureSource].
@Deprecated('Use SqfliteFileFixtureSource instead')
typedef SqfliteDataQuery = SqfliteFileFixtureSource;
