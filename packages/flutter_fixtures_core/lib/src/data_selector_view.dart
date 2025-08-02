import 'package:flutter_fixtures_core/src/fixture_document.dart';

import 'fixture_collection.dart';

/// Interface for UI components that allow users to pick a fixture
///
/// Implementations of this interface should provide a UI that allows
/// users to select a fixture from a collection.
abstract class DataSelectorView {
  /// Show a UI for picking a fixture from the collection
  ///
  /// This method should display a UI that allows the user to select
  /// a fixture from the provided collection, and return the selected fixture.
  Future<FixtureDocument?> pick(FixtureCollection fixture);
}
