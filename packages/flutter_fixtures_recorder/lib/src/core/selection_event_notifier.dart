import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// Interface for components that need to be notified of fixture selections
///
/// This interface allows custom data sources and components to integrate
/// with the recording/playback system. Implementations can track selection
/// events and provide recorded selections during playback.
abstract class SelectionEventNotifier {
  /// Notify when a fixture selection occurs
  ///
  /// This is called whenever a fixture is selected, allowing the recorder
  /// to capture the event. The [fixture] is the collection that was selected from,
  /// [selected] is the chosen document, and [source] identifies where the
  /// selection came from (e.g., 'dio', 'sqflite').
  void notifySelection(
    FixtureCollection fixture,
    FixtureDocument selected,
    String? source,
  );

  /// Check if a recorded selection exists for this fixture
  ///
  /// During playback, this returns the previously recorded selection for
  /// the given [fixture] collection, or null if no recording exists.
  /// This enables automatic selection of recorded choices without user interaction.
  FixtureDocument? getRecordedSelection(FixtureCollection fixture);
}
