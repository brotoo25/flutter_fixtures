import 'package:flutter/foundation.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'recording_session.dart';
import 'session_replay.dart';
import 'session_store.dart';

/// What the recorder is currently doing.
enum RecorderMode {
  /// Traffic passes through untouched.
  idle,

  /// Live responses are being captured into a new session.
  recording,

  /// Requests are answered from a saved session.
  replaying,
}

/// The record-and-replay controller — the engine behind core's
/// [TrafficRecorder] seam.
///
/// This is the module's single entry point: source adapters — the Dio
/// interceptor, the sqflite recording adapter, or any custom code talking
/// to any data source — feed captured traffic in through [record] and ask
/// [decide] how each request should be handled; UI — the built-in widgets
/// or your own — drives the mode transitions and session management. One
/// recorder serves every source at once: interactions are namespaced by
/// their request's `source`, so a session can hold HTTP and database
/// traffic side by side.
///
/// The recorder is a [ChangeNotifier]: it notifies on every mode change, on
/// every captured interaction, and on every replayed one, so any widget can
/// observe it (the built-in toolbar is nothing more than a listener on this
/// class). The stop-recording notification fires once the session is saved,
/// so a listener that lists sessions on idle sees the new one.
///
/// Mode transitions: recording can only start from [RecorderMode.idle];
/// replaying can start from idle or replaying (starting a replay while one
/// is active switches sessions). Starting either while recording throws a
/// [StateError]. The stop methods are safe to call in any mode.
class FixtureRecorder extends ChangeNotifier implements TrafficRecorder {
  final RecordingSessionStore _store;

  /// Optional custom request-key builder applied during replay.
  final RequestKeyBuilder? keyOf;

  RecorderMode _mode = RecorderMode.idle;
  final List<RecordedInteraction> _buffer = [];
  String? _pendingName;
  SessionReplay? _replay;

  FixtureRecorder({required RecordingSessionStore store, this.keyOf})
      : _store = store;

  /// The current mode.
  RecorderMode get mode => _mode;

  /// Whether the recorder is capturing traffic.
  bool get isRecording => _mode == RecorderMode.recording;

  /// Whether the recorder is answering requests from a saved session.
  bool get isReplaying => _mode == RecorderMode.replaying;

  /// How many interactions the in-progress recording has captured.
  int get recordedCount => _buffer.length;

  /// The session currently being replayed, if any.
  RecordingSession? get replaySession => _replay?.session;

  /// How many interactions the active replay has served since it
  /// (re)started; `0` when not replaying.
  int get replayedCount => _replay?.servedCount ?? 0;

  /// For each interaction of [replaySession] (by index), the 1-based order
  /// it was served in since the replay (re)started, or `null` if not yet;
  /// empty when not replaying. See [SessionReplay.serveOrder].
  List<int?> get replayServeOrder => _replay?.serveOrder ?? const [];

  /// Starts capturing traffic into a new session.
  ///
  /// The [name] can also be given (or overridden) at [stopRecording] time;
  /// a blank name means "use the default timestamped name". Throws a
  /// [StateError] unless the recorder is idle.
  void startRecording({String? name}) {
    if (_mode != RecorderMode.idle) {
      throw StateError(
          'Cannot start recording while ${_mode.name}. Stop it first.');
    }
    _pendingName = _normalizeName(name);
    _buffer.clear();
    _mode = RecorderMode.recording;
    notifyListeners();
  }

  /// Stops capturing and saves the session to the store.
  ///
  /// A blank [name] counts as absent, falling back to the name given at
  /// [startRecording] and then to a timestamped default. Returns the saved
  /// session, or `null` when there was nothing to save: the recorder was
  /// not recording, [discard] was set, or no traffic was captured.
  ///
  /// Capture stops immediately; listeners are notified once the session is
  /// saved, so [sessions] already reflects it.
  ///
  /// If the store fails to save, nothing is lost: the recorder returns to
  /// [RecorderMode.recording] with every captured interaction still in
  /// place (traffic during the failed attempt is not captured), the error
  /// propagates, and the caller can retry — with a different name or
  /// store — or [discard].
  Future<RecordingSession?> stopRecording({
    String? name,
    bool discard = false,
  }) async {
    if (!isRecording) return null;
    final interactions = List.of(_buffer);
    final pendingName = _pendingName;
    _buffer.clear();
    _pendingName = null;
    _mode = RecorderMode.idle;
    try {
      if (discard || interactions.isEmpty) return null;

      final recordedAt = DateTime.now();
      final session = RecordingSession(
        id: recordedAt.millisecondsSinceEpoch.toString(),
        name: _normalizeName(name) ??
            pendingName ??
            'Session ${_formatTimestamp(recordedAt)}',
        recordedAt: recordedAt,
        interactions: interactions,
      );
      try {
        await _store.save(session);
      } catch (_) {
        // Keep the recording so the caller can retry or discard it.
        _buffer.addAll(interactions);
        _pendingName = pendingName;
        _mode = RecorderMode.recording;
        rethrow;
      }
      return session;
    } finally {
      notifyListeners();
    }
  }

  /// Captures one interaction into the in-progress recording.
  ///
  /// Called by source adapters. [capture] is invoked only while recording,
  /// so adapters can call this unconditionally at zero idle cost.
  @override
  void record(RecordedInteraction Function() capture) {
    if (!isRecording) return;
    _buffer.add(capture());
    notifyListeners();
  }

  /// Loads the session with this id from the store and starts replaying it.
  ///
  /// Starting a replay while another is active switches sessions. Throws a
  /// [StateError] while recording, or if the id is unknown to the store.
  Future<RecordingSession> startReplay(String sessionId) async {
    _requireNotRecording('start replay');
    final session = await _store.load(sessionId);
    if (session == null) {
      throw StateError('Unknown recording session "$sessionId".');
    }
    startReplayOf(session);
    return session;
  }

  /// Starts replaying a session obtained elsewhere (built in code, imported,
  /// bundled as an asset).
  ///
  /// Starting a replay while another is active switches sessions. Throws a
  /// [StateError] while recording.
  void startReplayOf(RecordingSession session) {
    _requireNotRecording('start replay');
    _replay = SessionReplay(session, keyOf: keyOf);
    _mode = RecorderMode.replaying;
    notifyListeners();
  }

  /// Stops replaying. Safe to call in any mode.
  void stopReplay() {
    if (!isReplaying) return;
    _replay = null;
    _mode = RecorderMode.idle;
    notifyListeners();
  }

  /// Decides how a request should be handled, owning the whole replay
  /// choreography: mode check, ordered lookup (see [SessionReplay]), and
  /// the [onMiss] policy — including the phrasing of the miss message.
  ///
  /// [request] is invoked only while replaying, so idle traffic never pays
  /// for building a request description. Adapters translate the returned
  /// [ReplayDecision] into their native transport and nothing else.
  ///
  /// A replayed hit advances the session's progress ([replayedCount],
  /// [replayServeOrder]) and notifies listeners; misses do not.
  @override
  ReplayDecision decide(
    RecordedRequest Function() request, {
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
  }) {
    final replay = _replay;
    if (replay == null) return ForwardToSource();
    final resolved = request();
    final interaction = replay.next(resolved);
    if (interaction != null) {
      notifyListeners();
      return Replayed(interaction);
    }
    if (onMiss == ReplayMissBehavior.reject) {
      return RejectRequest(
        'No recorded response for "${resolved.operation} ${resolved.target}" '
        'in session "${replay.session.name}".',
      );
    }
    return ForwardToSource();
  }

  /// Rewinds the active replay to the beginning of its session.
  ///
  /// Notifies listeners, so UIs tracking replay progress can reset.
  void restartReplay() {
    final replay = _replay;
    if (replay == null) return;
    replay.restart();
    notifyListeners();
  }

  /// Summaries of all saved sessions, most recently recorded first.
  ///
  /// Listing never loads recorded payloads; use [startReplay] (or the
  /// store's `load`) to materialize a session.
  Future<List<RecordingSessionSummary>> sessions() => _store.list();

  /// Deletes a saved session.
  Future<void> deleteSession(String id) => _store.delete(id);

  void _requireNotRecording(String action) {
    if (isRecording) {
      throw StateError(
          'Cannot $action while recording. Stop the recording first.');
    }
  }

  static String? _normalizeName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _formatTimestamp(DateTime time) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} '
        '${pad(time.hour)}:${pad(time.minute)}';
  }
}
