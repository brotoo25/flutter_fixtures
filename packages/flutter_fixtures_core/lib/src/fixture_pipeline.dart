import 'dart:math' as math;

import 'data_selector_delay.dart';
import 'data_selector_type.dart';
import 'data_selector_view.dart';
import 'fixture_choice.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'fixture_source.dart';

/// The result of serving one request through a [FixturePipeline].
///
/// Either a [FixtureServed] (the selected document plus its payload) or a
/// [FixtureMiss] — which is also an [Exception], so adapters that fail on
/// a miss throw the outcome itself and consumers branch on its case
/// instead of parsing a message.
sealed class FixtureOutcome {
  const FixtureOutcome();
}

/// A request the pipeline could not serve. Carries its own message and is
/// throwable, so the case survives into whatever error an adapter raises.
sealed class FixtureMiss extends FixtureOutcome implements Exception {
  const FixtureMiss();

  /// Why the request was not served.
  String get message;

  @override
  String toString() => message;
}

/// No source had a fixture collection for the request.
class FixtureNotFound extends FixtureMiss {
  const FixtureNotFound();

  @override
  String get message => 'No fixture found for request.';
}

/// A collection was found, but it holds no documents to choose from.
class FixtureEmpty extends FixtureMiss {
  const FixtureEmpty();

  @override
  String get message => 'No fixture options found for request.';
}

/// The user dismissed the interactive pick without choosing.
class FixtureCancelled extends FixtureMiss {
  const FixtureCancelled();

  @override
  String get message => 'No fixture selected for request.';
}

/// A document was selected and its payload loaded.
class FixtureServed extends FixtureOutcome {
  const FixtureServed({required this.document, required this.payload});

  /// The selected document.
  final FixtureDocument document;

  /// The document's payload, as materialized by the resolving source.
  final Object? payload;
}

/// The Fixture Pipeline: everything between "here is a request" and "here
/// is the payload to serve", behind one call.
///
/// [serve] runs find → select → load against the pipeline's [source] and
/// reports a [FixtureOutcome]. Selection is owned entirely here — strategy
/// dispatch ([DataSelectorType]), auto-selecting single-option
/// collections, Selection Memory (choices the user asked to remember),
/// single-flight deduplication of concurrent interactive picks, and the
/// response [delay] — so a transport adapter holds one pipeline and only
/// renders outcomes in its native types.
///
/// Selection Memory lives in the pipeline instance: build one pipeline
/// per lifetime you want choices remembered for (typically once, next to
/// the client it serves), and hand the same instance to the adapter.
/// Building a pipeline per request silently forgets every remembered
/// choice.
///
/// ```dart
/// final pipeline = FixturePipeline(
///   source: HttpFileFixtureSource(),
///   selector: DataSelectorType.pick,
///   view: FixturesDialogView.of(context),
/// );
/// dio.interceptors.add(FixturesInterceptor(pipeline: pipeline));
/// ```
class FixturePipeline<TRequest> {
  /// Where fixture collections come from.
  final FixtureSource<TRequest> source;

  /// How a document is chosen from a collection.
  final DataSelectorType selector;

  /// The interactive picker used by [DataSelectorType.pick]; without one,
  /// pick falls back to the first document.
  final DataSelectorView? view;

  /// Applied before every served response, to simulate latency. Defaults
  /// to [DataSelectorDelay.instant]; any [Duration] works.
  final Duration delay;

  // Selection Memory: collection signature → remembered document id.
  final Map<String, String> _remembered = {};

  // In-flight interactive picks, so concurrent requests for the same
  // collection share one dialog.
  final Map<String, Future<FixtureChoice?>> _pendingPicks = {};

  FixturePipeline({
    required this.source,
    required this.selector,
    this.view,
    this.delay = DataSelectorDelay.instant,
  });

  /// Serves one request: finds its collection, selects a document, loads
  /// the payload.
  ///
  /// Never throws for a miss — [FixtureNotFound], [FixtureEmpty], and
  /// [FixtureCancelled] are returned as outcomes for the adapter to render
  /// (or throw). Exceptions from the source propagate.
  Future<FixtureOutcome> serve(TRequest request) async {
    final collection = await source.resolve(request);
    if (collection == null) {
      return const FixtureNotFound();
    }
    if (collection.items.isEmpty) {
      return const FixtureEmpty();
    }
    final document = await _select(collection);
    if (document == null) {
      return const FixtureCancelled();
    }
    return FixtureServed(
        document: document, payload: await source.data(document));
  }

  /// Forgets the remembered choice for this collection, so the next pick
  /// is interactive again.
  void clearRememberedSelectionFor(FixtureCollection fixture) {
    _remembered.remove(_signature(fixture));
  }

  /// Forgets every remembered choice.
  void clearRememberedSelections() => _remembered.clear();

  Future<FixtureDocument?> _select(FixtureCollection fixture) async {
    // A single option needs no strategy and no UI.
    if (fixture.items.length == 1) {
      await Future<void>.delayed(delay);
      return fixture.items.first;
    }

    if (selector == DataSelectorType.pick) {
      final remembered = _getRemembered(fixture);
      if (remembered != null) {
        await Future<void>.delayed(delay);
        return remembered;
      }
      final view = this.view;
      if (view == null) {
        await Future<void>.delayed(delay);
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
      await Future<void>.delayed(delay);
      return choice.document;
    }

    final selected = switch (selector) {
      DataSelectorType.defaultValue =>
        fixture.items.firstWhere((option) => option.defaultOption ?? false),
      DataSelectorType.random =>
        fixture.items[math.Random().nextInt(fixture.items.length)],
      DataSelectorType.pick => throw StateError('handled above'),
    };
    await Future<void>.delayed(delay);
    return selected;
  }

  FixtureDocument? _getRemembered(FixtureCollection fixture) {
    final id = _remembered[_signature(fixture)];
    if (id == null) return null;
    for (final doc in fixture.items) {
      if (doc.identifier == id) return doc;
    }
    return null;
  }

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
