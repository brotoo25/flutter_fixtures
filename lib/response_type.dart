import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fixtures/data_selector_type.dart';
import 'package:flutter_fixtures/fixture.dart';

class FixtureModel {
  final String description;
  final List<FixtureValue> items;

  FixtureModel(this.description, this.items);

  factory FixtureModel.fromJson(Map<String, dynamic> json) => FixtureModel(
        json['description'] as String,
        (json['values'] as List<dynamic>)
            .map((option) => FixtureValue.fromJson(option))
            .toList(),
      );
}

class FixtureValue {
  final String identifier;
  final String description;
  final bool? defaultOption;
  final dynamic data;
  final String? dataPath;

  FixtureValue({
    required this.identifier,
    required this.description,
    required this.defaultOption,
    this.data,
    this.dataPath,
  });

  factory FixtureValue.fromJson(Map<String, dynamic> json) => FixtureValue(
        identifier: json['identifier'] as String,
        description: json['description'] as String,
        defaultOption: json['default'] as bool? ?? false,
        data: json['data'],
        dataPath: json['dataPath'],
      );
}

mixin Fixture<Input, Output> {
  Future<Output?> find(Input input);
  Future<Output?> data(FixtureDocument document);
  Future<FixtureCollection> parse(Output source);

  Future<FixtureDocument?> select(
    FixtureModel fixture,
    DataSelectorView? view,
    DataSelectorType selector,
  ) async {
    final selectedOption = switch (selector) {
      Pick() => await view?.pick(fixture),
      Default() =>
        fixture.items.firstWhere((option) => option.defaultOption ?? false),
      Random() => fixture.items[math.Random().nextInt(fixture.items.length)],
    };

    return selectedOption;
  }
}

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
