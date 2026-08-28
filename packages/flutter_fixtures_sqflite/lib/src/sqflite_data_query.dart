import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'sqflite_fixture_source.dart';
import 'sqflite_query.dart';

/// The [SqfliteFixtureSource] backed by fixture files.
///
/// Maps a database query to fixture-file candidates (see
/// [SqfliteQuery.fixtureCandidates]) and delegates loading to
/// [FixtureSource].
///
/// ## Fixture File Format
///
/// Fixture files should be JSON files with the following structure:
///
/// ```json
/// {
///   "description": "User table query fixtures",
///   "values": [
///     {
///       "identifier": "success",
///       "description": "Returns list of users",
///       "default": true,
///       "data": [
///         {"id": 1, "name": "John"},
///         {"id": 2, "name": "Jane"}
///       ]
///     },
///     {
///       "identifier": "empty",
///       "description": "Returns empty result",
///       "data": []
///     }
///   ]
/// }
/// ```
///
/// ## File Naming Convention
///
/// Files should be named based on the query operation and table:
/// - `query_users.json` for SELECT queries on users table
/// - `insert_users.json` for INSERT operations on users table
/// - `query_users_id_1.json` for queries with WHERE clause
class SqfliteDataQuery implements SqfliteFixtureSource {
  /// The folder where mock data is stored
  final String mockFolder;

  final FixtureSource _source;

  /// Creates a new SqfliteDataQuery with the specified mock folder
  ///
  /// [assetLoader] substitutes how fixture files are read; it defaults to
  /// the root asset bundle.
  SqfliteDataQuery({
    this.mockFolder = 'assets/fixtures/database',
    FixtureAssetLoader assetLoader = const BundleAssetLoader(),
  }) : _source =
            FixtureSource(mockFolder: mockFolder, assetLoader: assetLoader);

  @override
  Future<FixtureCollection?> find(SqfliteQuery query) async {
    final json = await _source.resolve(query.fixtureCandidates);
    return json == null ? null : FixtureCollection.fromJson(json);
  }

  @override
  Future<Object?> data(FixtureDocument document) {
    return _source.data(document);
  }
}
