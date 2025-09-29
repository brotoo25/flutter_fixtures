import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Implementation of DataQuery for Dio HTTP client
///
/// This class provides functionality for finding and parsing fixture data
/// for Dio HTTP requests.
class DioDataQuery with FixtureSelector implements DataQuery<RequestOptions, Map<String, dynamic>> {
  /// The folder where mock data is stored
  final String mockFolder;

  /// Creates a new DioDataQuery with the specified mock folder
  DioDataQuery({
    this.mockFolder = 'assets/fixtures',
  });

  /// Gets the mock folder path
  String get mockFolderPath => mockFolder;

  @override
  Future<Map<String, dynamic>?> find(RequestOptions input) async {
    // Base file name from method and path (slashes replaced by underscores)
    final base = '${input.method}${input.path.replaceAll('/', '_')}';

    // Prepare query parameter segments (deterministic order by key)
    final queryParams = input.queryParameters;
    final sortedKeys = queryParams.keys.toList()..sort((a, b) => a.compareTo(b));

    String normalizeSegment(dynamic value) {
      final str = value is List
          ? value.map((v) => (v ?? '').toString()).join('-')
          : (value ?? '').toString();
      return str.replaceAll('/', '_').replaceAll(' ', '_');
    }

    final valueSegments = [
      for (final k in sortedKeys) normalizeSegment(queryParams[k]),
    ].where((s) => s.isNotEmpty).toList();

    // Build a list of candidate file paths to try, in order
    final List<String> candidates = [
      // 1) Exact (no query params)
      '$mockFolder/$base.json',
      if (valueSegments.isNotEmpty) ...[
        // 2) Values appended (e.g., GET_search_foo_2.json)
        '$mockFolder/${base}_${valueSegments.join('_')}.json',
        // 3) Wildcards for each query value (e.g., GET_search_*.json or GET_search_*_*.json)
        '$mockFolder/${base}_${List.filled(valueSegments.length, '*').join('_')}.json',
        // 4) Mustache named by key order (e.g., GET_search_{{q}}_{{page}}.json)
        if (sortedKeys.isNotEmpty)
          '$mockFolder/${base}_${sortedKeys.map((k) => '{{$k}}').join('_')}.json',
      ],
    ];

    // Try exact matches first, then look for mustache pattern matches
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
      description: source['description'],
      items: (source['values'] as List)
          .map((option) => FixtureDocument(
                identifier: option['identifier'] as String,
                description: option['description'] as String,
                defaultOption: option['default'] as bool? ?? false,
                data: option['data'],
                dataPath: option['dataPath'],
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

    // Return inline data
    if (document.data != null) {
      return document.data;
    }

    // Load data from file
    final response = await rootBundle.loadString('$mockFolder/${document.dataPath}');
    final data = jsonDecode(response);

    return data;
  }
}
