import 'dart:math' as math;

import 'data_selector_delay.dart';
import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_choice.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'fixture_pipeline.dart';

/// Mixin that provides the fixture selection flow for data sources.
///
/// This is the single home of selection behavior: strategy dispatch,
/// auto-selecting single-option collections, remembered choices (both the
/// read and the write), deduplication of concurrent interactive picks, and
/// response delays. Views ([DataSelectorView]) only present options and
/// report the user's answer.
///
/// Remembered choices and in-flight picks are scoped to the mixing-in
/// instance and keyed by one collection signature, so the two stores can
/// never disagree about what "the same collection" means.
mixin FixtureSelector {
  /// Remembered document identifiers, keyed by collection signature.
  ///
  /// Runtime-only by design, to avoid persistence dependencies.
  final Map<String, String> _remembered = {};

  /// In-flight interactive picks, keyed by collection signature.
  ///
  /// Concurrent [select] calls for the same collection share one view
  /// interaction instead of stacking UIs.
  final Map<String, Future<FixtureChoice?>> _pendingPicks = {};

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
      final remembered = _getRemembered(fixture);
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
        _remembered[_signature(fixture)] = choice.document.identifier;
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

  /// Runs the full fixture pipeline: obtain a collection through [find],
  /// select a document, and load its payload through [data].
  ///
  /// This is the one home of the find → select → data choreography;
  /// adapters map the returned [FixtureOutcome] to their domain (an HTTP
  /// response, database rows) and keep their own error policy.
  Future<FixtureOutcome> serve({
    required Future<FixtureCollection?> Function() find,
    required Future<Object?> Function(FixtureDocument document) data,
    DataSelectorView? view,
    required DataSelectorType selector,
    DataSelectorDelay delay = DataSelectorDelay.instant,
  }) async {
    final collection = await find();
    if (collection == null) {
      return const FixtureNotFound();
    }
    if (collection.items.isEmpty) {
      return const FixtureEmpty();
    }
    final document = await select(collection, view, selector, delay: delay);
    if (document == null) {
      return const FixtureCancelled();
    }
    return FixtureServed(document: document, payload: await data(document));
  }

  /// Clears the remembered choice for [fixture] on this selector.
  void clearRememberedSelectionFor(FixtureCollection fixture) {
    _remembered.remove(_signature(fixture));
  }

  /// Clears all remembered choices on this selector.
  void clearRememberedSelections() => _remembered.clear();

  /// The remembered document for this collection, if it still exists in it.
  FixtureDocument? _getRemembered(FixtureCollection fixture) {
    final id = _remembered[_signature(fixture)];
    if (id == null) return null;
    for (final doc in fixture.items) {
      if (doc.identifier == id) return doc;
    }
    return null;
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
