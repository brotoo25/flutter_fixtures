import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Implementation of DataQuery for Dio HTTP client
///
/// This class provides functionality for finding and parsing fixture data
/// for Dio HTTP requests.
class DioDataQuery
    with FixtureSelector
    implements DataQuery<RequestOptions, Map<String, dynamic>> {
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
    final fileName =
        '$mockFolder/${input.method}${input.path.replaceAll('/', '_')}.json';
    final response = await rootBundle.loadString(fileName);
    final data = jsonDecode(response);

    return data;
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
    final response =
        await rootBundle.loadString('$mockFolder/${document.dataPath}');
    final data = jsonDecode(response);

    return data;
  }
}
