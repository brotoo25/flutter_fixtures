import 'package:flutter/foundation.dart';

import 'recorded_interaction.dart';
import 'recorded_request.dart';
import 'recording_session.dart';
import 'replay_decision.dart';
import 'replay_miss_behavior.dart';
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

/// The record-and-replay controller.
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
/// The recorder is a [ChangeNotifier]: it notifies on every mode change and
/// on every captured interaction, so any widget can observe it (the built-in
/// toolbar is nothing more than a listener on this class).
///
/// Mode transitions: recording can only start from [RecorderMode.idle];
/// replaying can start from idle or replaying (starting a replay while one
/// is active switches sessions). Starting either while recording throws a
/// [StateError]. The stop methods are safe to call in any mode.
class FixtureRecorder extends ChangeNotifier {
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

  /// Starts capturing traffic into a new session.
  ///
  /// The [name] can also be given (or overridden) at [stopRecording] time;
  /// a blank name means "use the default timestamped name". Throws a
  /// [StateError] unless the recorder is idle.
  void startRecording({String? name}) {
    _requireNotRecording('start recording');
    if (isReplaying) {
      throw StateError(
          'Cannot start recording while replaying. Stop the replay first.');
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
    notifyListeners();

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
    await _store.save(session);
    return session;
  }

  /// Captures one interaction into the in-progress recording.
  ///
  /// Called by source adapters. Does nothing unless recording, so adapters
  /// can call it unconditionally.
  void record(RecordedInteraction interaction) {
    if (!isRecording) return;
    _buffer.add(interaction);
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
  /// Adapters translate the returned [ReplayDecision] into their native
  /// transport and nothing else.
  ReplayDecision decide(
    RecordedRequest request, {
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
  }) {
    final replay = _replay;
    if (replay == null) return ForwardToSource();
    final interaction = replay.next(request);
    if (interaction != null) return Replayed(interaction);
    if (onMiss == ReplayMissBehavior.reject) {
      return RejectRequest(
        'No recorded response for "${request.operation} ${request.target}" '
        'in session "${replay.session.name}".',
      );
    }
    return ForwardToSource();
  }

  /// Rewinds the active replay to the beginning of its session.
  void restartReplay() => _replay?.restart();

  /// All saved sessions, most recently recorded first.
  Future<List<RecordingSession>> sessions() => _store.list();

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
