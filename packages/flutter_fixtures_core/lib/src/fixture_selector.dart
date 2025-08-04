import 'dart:math' as math;

import 'package:flutter_fixtures_core/src/fixture_document.dart';

import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_collection.dart';

/// Mixin that provides fixture functionality for data sources
///
/// This mixin provides common functionality for working with fixtures,
/// including finding, parsing, and selecting fixtures.
mixin FixtureSelector {
  /// Select a fixture document from a collection based on the selector type
  ///
  /// This method uses the provided selector type to choose a fixture document
  /// from the collection, potentially using the view for user selection.
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector,
  ) async {
    final selectedOption = switch (selector) {
      Pick() => await view?.pick(fixture) ?? fixture.items.first,
      Default() => fixture.items.firstWhere((option) => option.defaultOption ?? false),
      Random() => fixture.items[math.Random().nextInt(fixture.items.length)],
    };

    return selectedOption;
  }
}
