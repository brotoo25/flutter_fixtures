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
  final Map<String, List<RecordedInteraction>> _byKey = {};
  final Map<String, int> _cursors = {};

  SessionReplay(this.session, {RequestKeyBuilder? keyOf})
      : _keyOf = keyOf ?? RecordedRequest.defaultKey {
    for (final interaction in session.interactions) {
      _byKey
          .putIfAbsent(_keyOf(interaction.request), () => [])
          .add(interaction);
    }
  }

  /// Returns the next recorded response for this request, or `null` if the
  /// session holds no recording for it — including when the key's
  /// recordings have all been served.
  RecordedInteraction? next(RecordedRequest request) {
    final key = _keyOf(request);
    final recordings = _byKey[key];
    if (recordings == null) return null;
    final cursor = _cursors[key] ?? 0;
    if (cursor >= recordings.length) return null;
    _cursors[key] = cursor + 1;
    return recordings[cursor];
  }

  /// Rewinds every per-key cursor to the beginning of the session.
  void restart() => _cursors.clear();
}
