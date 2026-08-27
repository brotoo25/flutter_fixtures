import 'fixture_choice.dart';
import 'fixture_collection.dart';

/// Interface for UI components that allow users to pick a fixture
///
/// Implementations of this interface should provide a UI that allows
/// users to select a fixture from a collection.
///
/// Implementations only present options and report the user's answer.
/// Remembering choices, deduplicating concurrent requests, and applying
/// delays are handled by the selection logic in core ([FixtureSelector]),
/// so custom views get those behaviors for free.
abstract class DataSelectorView {
  /// Show a UI for picking a fixture from the collection
  ///
  /// Returns the user's [FixtureChoice], or `null` if the user cancelled.
  Future<FixtureChoice?> pick(FixtureCollection fixture);
}
