import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'recording_session.dart';

/// Plays back a Recording Session, serving responses in recorded order.
///
/// Interactions are grouped by request key (see [RequestKeyBuilder]); each
/// key keeps its own cursor. Repeated requests with the same key receive
/// the responses in the order they were recorded — so a polling endpoint
/// that was captured returning `pending`, `pending`, `done` replays exactly
/// that progression. Each recording is served exactly once: when a key's
/// recordings are exhausted, further requests are misses, making the end
/// of the session's scope explicit instead of silently repeating stale
/// responses. [restart] rewinds every cursor for another pass.
///
/// Progress is observable: [servedCount] is how many interactions have
/// been served since the last (re)start, and [serveOrder] records, per
/// interaction index, the order it was served in — what a timeline UI
/// needs, without re-deriving keys or cursors outside the engine.
///
/// The engine is source-agnostic: keys start with the request's source, so
/// HTTP traffic, database queries, and custom sources coexist in one
/// session without colliding.
///
/// A miss — a key that was never recorded, or one whose recordings are
/// used up — returns `null`; what happens then (forward to the real
/// source, fail) is the adapter's policy, not this class's — see
/// `ReplayMissBehavior`.
class SessionReplay {
  /// The session being replayed.
  final RecordingSession session;

  final RequestKeyBuilder _keyOf;

  // Interaction indices per key, in recorded order.
  final Map<String, List<int>> _indicesByKey = {};
  final Map<String, int> _cursors = {};
  late final List<int?> _serveOrder;
  int _servedCount = 0;

  SessionReplay(this.session, {RequestKeyBuilder? keyOf})
      : _keyOf = keyOf ?? RecordedRequest.defaultKey {
    final interactions = session.interactions;
    for (var i = 0; i < interactions.length; i++) {
      _indicesByKey
          .putIfAbsent(_keyOf(interactions[i].request), () => [])
          .add(i);
    }
    _serveOrder = List<int?>.filled(interactions.length, null);
  }

  /// How many interactions have been served since the last (re)start.
  int get servedCount => _servedCount;

  /// For each interaction in [session] (by index), the 1-based order in
  /// which it was served since the last (re)start, or `null` if it has not
  /// been served yet.
  List<int?> get serveOrder => List.unmodifiable(_serveOrder);

  /// Returns the next recorded response for this request, or `null` if the
  /// session holds no recording for it — including when the key's
  /// recordings have all been served.
  RecordedInteraction? next(RecordedRequest request) {
    final key = _keyOf(request);
    final indices = _indicesByKey[key];
    if (indices == null) return null;
    final cursor = _cursors[key] ?? 0;
    if (cursor >= indices.length) return null;
    _cursors[key] = cursor + 1;
    final index = indices[cursor];
    _serveOrder[index] = ++_servedCount;
    return session.interactions[index];
  }

  /// Rewinds every per-key cursor to the beginning of the session and
  /// clears the serve order.
  void restart() {
    _cursors.clear();
    _serveOrder.fillRange(0, _serveOrder.length, null);
    _servedCount = 0;
  }
}
