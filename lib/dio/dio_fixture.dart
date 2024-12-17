import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fixtures/fixture.dart';

class DioFixture with Fixture<RequestOptions, Map<String, dynamic>> {
  final String mockFolder;

  DioFixture({
    this.mockFolder = 'fixtures',
  });

  @override
  Future<Map<String, dynamic>?> find(RequestOptions input) async {
    final fileName =
        '$mockFolder/${input.method}${input.path.replaceAll('/', '_')}.json';
    final response = await rootBundle.loadString('assets/$fileName');
    final data = jsonDecode(response);

    return data;
  }

  @override
  Future<FixtureCollection> parse(Map<String, dynamic> source) async {
    return FixtureCollection.fromJson(source);
  }

  @override
  Future<Map<String, dynamic>?> data(FixtureDocument payload) async {
    if (payload.data == null && payload.dataPath == null) return null;

    assert(payload.data != null && payload.dataPath != null,
        'Either data or dataPath must be provided by fixture DataModel but not both.');

    if (payload.data != null) return payload.data;

    final response =
        await rootBundle.loadString('assets/$mockFolder/${payload.dataPath}');
    return jsonDecode(response);
  }
}
