import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import '../core/selection_event_notifier.dart';

/// Data selector wrapper for playback mode
///
/// During playback, this wrapper tries to automatically select recorded
/// fixtures. If no recording exists for a fixture, it falls back to the
/// provided fallback selector.
///
/// Note: This is not a true [DataSelectorType] subclass since that's sealed.
/// Instead, it's used by [RecordableDataQuery] to intercept selection logic.
class PlaybackDataSelector {
  /// The recorder that provides recorded selections
  final SelectionEventNotifier recorder;

  /// The fallback selector to use when no recording exists
  final DataSelectorType fallback;

  /// Creates a playback data selector
  ///
  /// The [recorder] is queried for recorded selections, and [fallback]
  /// is used when no recording exists for a fixture.
  PlaybackDataSelector({
    required this.recorder,
    required this.fallback,
  });
}
