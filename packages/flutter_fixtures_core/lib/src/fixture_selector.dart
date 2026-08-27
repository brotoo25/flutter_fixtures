import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'data_selector_delay.dart';
import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_choice.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'fixture_selection_memory.dart';

/// Mixin that provides the fixture selection flow for data sources.
///
/// This is the single home of selection behavior: strategy dispatch,
/// auto-selecting single-option collections, remembered choices (both the
/// read and the write), deduplication of concurrent interactive picks, and
/// response delays. Views ([DataSelectorView]) only present options and
/// report the user's answer.
mixin FixtureSelector {
  /// In-flight interactive picks, keyed by collection signature.
  ///
  /// Concurrent [select] calls for the same collection (e.g. several
  /// interceptors handling the same request) share one view interaction
  /// instead of stacking UIs. Static so the guarantee holds across
  /// data-source instances, mirroring [FixtureSelectionMemory].
  static final Map<String, Future<FixtureChoice?>> _pendingPicks = {};

  /// Clears in-flight pick tracking. Intended for test isolation.
  @visibleForTesting
  static void clearPendingPicks() => _pendingPicks.clear();

  /// Select a fixture document from a collection based on the selector type
  ///
  /// Uses the provided selector type to choose a fixture document from the
  /// collection, potentially using the view for user selection.
  ///
  /// Returns `null` when the user cancelled an interactive pick. With no
  /// [view] configured, [DataSelectorType.pick] falls back to the first item.
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

    if (selector == DataSelectorType.pick) {
      final remembered = FixtureSelectionMemory.getRemembered(fixture);
      if (remembered != null) {
        await delay.apply();
        return remembered;
      }

      if (view == null) {
        await delay.apply();
        return fixture.items.first;
      }

      final choice = await _pickOnce(fixture, view);
      if (choice == null) {
        // User cancelled — propagate instead of silently picking an item.
        return null;
      }
      if (choice.remember) {
        FixtureSelectionMemory.remember(fixture, choice.document);
      }
      await delay.apply();
      return choice.document;
    }

    final selectedOption = switch (selector) {
      DataSelectorType.defaultValue =>
        fixture.items.firstWhere((option) => option.defaultOption ?? false),
      DataSelectorType.random =>
        fixture.items[math.Random().nextInt(fixture.items.length)],
      DataSelectorType.pick => throw StateError('handled above'),
    };

    await delay.apply();
    return selectedOption;
  }

  /// Runs [view.pick], sharing one in-flight interaction per collection.
  Future<FixtureChoice?> _pickOnce(
    FixtureCollection fixture,
    DataSelectorView view,
  ) {
    final key = _signature(fixture);
    final pending = _pendingPicks[key];
    if (pending != null) {
      return pending;
    }

    late final Future<FixtureChoice?> request;
    request = view.pick(fixture).whenComplete(() {
      if (identical(_pendingPicks[key], request)) {
        _pendingPicks.remove(key);
      }
    });
    _pendingPicks[key] = request;
    return request;
  }

  static String _signature(FixtureCollection fixture) {
    final buffer = StringBuffer(fixture.description);
    for (final item in fixture.items) {
      buffer
        ..write('|')
        ..write(item.identifier)
        ..write('|')
        ..write(item.description)
        ..write('|')
        ..write(item.defaultOption ?? false)
        ..write('|')
        ..write(item.dataPath ?? '');
    }
    return buffer.toString();
  }
}
