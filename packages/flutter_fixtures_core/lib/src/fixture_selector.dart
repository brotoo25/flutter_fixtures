import 'dart:math' as math;

import 'package:flutter_fixtures_core/src/fixture_document.dart';

import 'data_selector_delay.dart';
import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_collection.dart';
import 'fixture_selection_memory.dart';

/// Mixin that provides fixture functionality for data sources
///
/// This mixin provides common functionality for working with fixtures,
/// including finding, parsing, and selecting fixtures.
mixin FixtureSelector {
  /// Select a fixture document from a collection based on the selector type
  ///
  /// This method uses the provided selector type to choose a fixture document
  /// from the collection, potentially using the view for user selection.
  ///
  /// The optional [delay] parameter allows simulating response delays.
  /// Defaults to [DataSelectorDelay.instant] (no delay).
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector, {
    DataSelectorDelay delay = DataSelectorDelay.instant,
  }) async {
    // If there's only one option, skip any UI and return it directly.
    if (fixture.items.length == 1) {
      await delay.apply();
      return fixture.items.first;
    }

    // If using Pick selector and a remembered choice exists, use it.
    if (selector is Pick) {
      final remembered = FixtureSelectionMemory.getRemembered(fixture);
      if (remembered != null) {
        await delay.apply();
        return remembered;
      }
    }

    // Otherwise, use strategy-specific logic
    final selectedOption = switch (selector) {
      Pick() => fixture.items.length == 1
          ? fixture.items.first
          : await view?.pick(fixture) ?? fixture.items.first,
      Default() =>
        fixture.items.firstWhere((option) => option.defaultOption ?? false),
      Random() => fixture.items[math.Random().nextInt(fixture.items.length)],
    };

    // Apply delay before returning
    await delay.apply();

    return selectedOption;
  }
}
