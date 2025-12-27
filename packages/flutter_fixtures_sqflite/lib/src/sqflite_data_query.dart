import 'dart:convert';

import 'package:flutter/services.dart';
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

  /// Creates a new SqfliteDataQuery with the specified mock folder
  SqfliteDataQuery({
    this.mockFolder = 'assets/fixtures/database',
  });

  /// Gets the mock folder path
  String get mockFolderPath => mockFolder;

  @override
  Future<Map<String, dynamic>?> find(SqfliteQuery input) async {
    final identifier = input.fixtureIdentifier;

    // Build candidate file paths to try
    final List<String> candidates = [
      '$mockFolder/$identifier.json',
    ];

    // For table queries with where clause, also try without the where clause
    if (input.table != null && input.where != null) {
      candidates.add('$mockFolder/${input.operation.name}_${input.table}.json');
    }

    // Try each candidate path
    for (final path in candidates) {
      try {
        final response = await rootBundle.loadString(path);
        final data = jsonDecode(response);
        return data as Map<String, dynamic>;
      } catch (_) {
        // Try next candidate
        continue;
      }
    }

    // No candidates matched
    return null;
  }

  @override
  Future<FixtureCollection?> parse(Map<String, dynamic> source) async {
    return FixtureCollection(
      description: source['description'] as String? ?? '',
      items: (source['values'] as List)
          .map((option) => FixtureDocument(
                identifier: option['identifier'] as String,
                description: option['description'] as String,
                defaultOption: option['default'] as bool? ?? false,
                data: option['data'],
                dataPath: option['dataPath'] as String?,
              ))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument document) async {
    if (document.data == null && document.dataPath == null) {
      return null;
    }

    if (document.data != null && document.dataPath != null) {
      throw AssertionError(
        'Either data or dataPath must be provided by fixture document but not both.',
      );
    }

    // Return inline data (wrap in result key for consistency)
    if (document.data != null) {
      // If data is a List, wrap it; if Map, return as-is
      if (document.data is List) {
        return {'result': document.data};
      }
      return document.data as Map<String, dynamic>;
    }

    // Load data from file
    final response =
        await rootBundle.loadString('$mockFolder/${document.dataPath}');
    final data = jsonDecode(response);

    if (data is List) {
      return {'result': data};
    }
    return data as Map<String, dynamic>;
  }
}
