import 'dart:math' as math;

import 'package:flutter_fixtures/data_selector_type.dart';

class FixtureCollection {
  final String description;
  final List<FixtureDocument> items;

  FixtureCollection(this.description, this.items);

  factory FixtureCollection.fromJson(Map<String, dynamic> json) => FixtureCollection(
        json['description'] as String,
        (json['values'] as List<dynamic>)
            .map((option) => FixtureDocument.fromJson(option))
            .toList(),
      );
}

class FixtureDocument {
  final String identifier;
  final String description;
  final bool? defaultOption;
  final dynamic data;
  final String? dataPath;

  FixtureDocument({
    required this.identifier,
    required this.description,
    required this.defaultOption,
    this.data,
    this.dataPath,
  });

  factory FixtureDocument.fromJson(Map<String, dynamic> json) => FixtureDocument(
        identifier: json['identifier'] as String,
        description: json['description'] as String,
        defaultOption: json['default'] as bool? ?? false,
        data: json['data'],
        dataPath: json['dataPath'],
      );
}

abstract class DataSelectorView {
  Future<FixtureDocument?> pick(FixtureCollection fixture);
}

mixin Fixture<Input, Output> {
  Future<Output?> find(Input input);
  Future<Output?> data(FixtureDocument payload);
  Future<FixtureCollection> parse(Output source);

  Future<FixtureDocument?> select(
    FixtureCollection fixture,
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
