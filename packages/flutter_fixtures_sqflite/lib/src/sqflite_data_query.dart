import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'sqflite_query.dart';

/// Implementation of DataQuery for SQLite/sqflite database operations
///
/// This class provides functionality for finding and parsing fixture data
/// for SQLite database queries. It allows mocking database responses using
/// fixture files, similar to how DioDataQuery mocks HTTP responses.
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
class SqfliteDataQuery
    with FixtureSelector
    implements DataQuery<SqfliteQuery, Map<String, dynamic>> {
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

  /// Gets the mock folder path
  String get mockFolderPath => mockFolder;

  @override
  Future<Map<String, dynamic>?> find(SqfliteQuery input) {
    return _source.resolve([
      '${input.fixtureIdentifier}.json',
      // For table queries with a where clause, also try without it.
      if (input.table != null && input.where != null)
        '${input.operation.name}_${input.table}.json',
    ]);
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    return FixtureCollection.fromJson(source);
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    if (document.data == null && document.dataPath == null) {
      return null;
    }

    final data = await _source.data(document);

    // Wrap list payloads in a result key for a consistent map shape.
    if (data is List) {
      return {'result': data};
    }
    return (data as Map).cast<String, dynamic>();
  }
}
