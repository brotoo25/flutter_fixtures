import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import '../core/selection_event_notifier.dart';

/// Wrapper for [DataQuery] that adds recording and playback capabilities
///
/// This decorator wraps any [DataQuery] implementation to intercept fixture
/// selections. During recording mode, it notifies the recorder of selections.
/// During playback mode, it automatically selects recorded fixtures.
///
/// The wrapper is transparent - it implements the same [DataQuery] interface
/// and delegates all calls except [select] to the wrapped implementation.
class RecordableDataQuery<Input, Output> implements DataQuery<Input, Output> {
  /// The underlying data query implementation
  final DataQuery<Input, Output> delegate;

  /// The recorder to notify of selections and query for playback
  final SelectionEventNotifier recorder;

  /// Source identifier for recorded events (e.g., 'dio', 'sqflite')
  final String? source;

  /// Creates a recordable data query wrapper
  ///
  /// The [delegate] is the original data query to wrap, [recorder] provides
  /// recording/playback functionality, and [source] identifies where selections
  /// come from for debugging purposes.
  RecordableDataQuery({
    required this.delegate,
    required this.recorder,
    this.source,
  });

  @override
  Future<Output?> find(Input input) => delegate.find(input);

  @override
  Future<FixtureCollection?> parse(Output source) => delegate.parse(source);

  @override
  Future<Output?> data(FixtureDocument document) => delegate.data(document);

  @override
  Future<FixtureDocument?> select(
    FixtureCollection fixture,
    DataSelectorView? view,
    DataSelectorType selector, {
    DataSelectorDelay delay = DataSelectorDelay.instant,
  }) async {
    // Handle playback mode if using PlaybackDataSelector
    // Note: We check the recorder directly since PlaybackDataSelector
    // is not a true DataSelectorType (sealed class limitation)
    final recorded = recorder.getRecordedSelection(fixture);
    if (recorded != null) {
      await delay.apply();
      return recorded; // Strict match found, use recorded selection
    }

    // No recording found, or not in playback mode - proceed with normal selection
    final selected =
        await delegate.select(fixture, view, selector, delay: delay);

    // Notify recorder of the selection (will be filtered by recorder if needed)
    if (selected != null) {
      recorder.notifySelection(fixture, selected, source);
    }

    return selected;
  }
}
