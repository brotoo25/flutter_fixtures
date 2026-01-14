import 'package:flutter/foundation.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import '../core/recorder_mode.dart';
import '../core/recording_event.dart';
import '../core/recording_session.dart';
import '../core/selection_event_notifier.dart';
import '../storage/session_metadata.dart';
import '../storage/session_storage.dart';

/// Main service for recording and playing back fixture selections
///
/// The recorder manages three modes:
/// - [RecorderMode.idle]: Normal operation, no recording or playback
/// - [RecorderMode.recording]: Captures user fixture selections
/// - [RecorderMode.playback]: Automatically selects recorded fixtures
///
/// Extends [ChangeNotifier] to notify UI components of mode changes.
class FixtureRecorder extends ChangeNotifier implements SelectionEventNotifier {
  final SessionStorage _storage;

  RecorderMode _mode = RecorderMode.idle;
  RecordingSession? _currentSession;
  final List<RecordingEvent> _recordingBuffer = [];
  int _playbackIndex = 0; // Current position in playback events list
  String? _lastRecordedKey;
  String? _lastRecordedIdentifier;

  /// Creates a fixture recorder with the specified storage backend
  FixtureRecorder({required SessionStorage storage}) : _storage = storage;

  /// Current mode of the recorder
  RecorderMode get mode => _mode;

  /// Current session being recorded or played (null if idle)
  RecordingSession? get currentSession => _currentSession;

  /// Current playback index (position in the events list)
  int get playbackIndex => _playbackIndex;

  /// Total number of events in current session
  int get totalEvents => _currentSession?.events.length ?? 0;

  /// Whether playback has remaining events
  bool get hasRemainingEvents =>
      _mode == RecorderMode.playback &&
      _currentSession != null &&
      _playbackIndex < _currentSession!.events.length;

  /// Number of events currently in the recording buffer
  int get recordingBufferSize => _recordingBuffer.length;

  /// Start recording fixture selections
  ///
  /// Clears any previous recording buffer and enters recording mode.
  /// Selections will be captured until [stopRecording] or [cancelRecording] is called.
  void startRecording() {
    _mode = RecorderMode.recording;
    _recordingBuffer.clear();
    _lastRecordedKey = null;
    _lastRecordedIdentifier = null;
    notifyListeners();
  }

  /// Stop recording and save the session
  ///
  /// Creates a [RecordingSession] with the given [sessionName] and saves it
  /// to storage. Returns to idle mode after saving.
  Future<void> stopRecording(String sessionName) async {
    if (_mode != RecorderMode.recording) return;

    final session = RecordingSession(
      name: sessionName,
      createdAt: DateTime.now(),
      events: List.from(_recordingBuffer),
    );

    await _storage.saveSession(session);
    _recordingBuffer.clear();
    _mode = RecorderMode.idle;
    _lastRecordedKey = null;
    _lastRecordedIdentifier = null;
    notifyListeners();
  }

  /// Cancel recording without saving
  ///
  /// Discards all recorded events and returns to idle mode.
  void cancelRecording() {
    _recordingBuffer.clear();
    _mode = RecorderMode.idle;
    _lastRecordedKey = null;
    _lastRecordedIdentifier = null;
    notifyListeners();
  }

  @override
  void notifySelection(
    FixtureCollection fixture,
    FixtureDocument selected,
    String? source,
  ) {
    if (_mode != RecorderMode.recording) return;

    // Skip default selections (requirement)
    if (selected.defaultOption == true) return;

    // Skip consecutive repeats (requirement)
    final fixtureKey = fixture.description;
    if (_lastRecordedKey == fixtureKey &&
        _lastRecordedIdentifier == selected.identifier) {
      return;
    }

    _recordingBuffer.add(
      RecordingEvent(
        fixtureKey: fixtureKey,
        selectedIdentifier: selected.identifier,
        timestamp: DateTime.now(),
        source: source,
      ),
    );

    _lastRecordedKey = fixtureKey;
    _lastRecordedIdentifier = selected.identifier;
    notifyListeners();
  }

  /// Start playing back a recorded session
  ///
  /// Loads the session with the given [sessionName] and enters playback mode.
  /// The recorder will provide recorded selections via [getRecordedSelection].
  /// Also updates the session's lastUsedAt timestamp.
  Future<void> startPlayback(String sessionName) async {
    final session = await _storage.loadSession(sessionName);
    if (session == null) return;

    _currentSession = session;
    _playbackIndex = 0;

    // Update lastUsedAt
    final updatedSession = RecordingSession(
      name: session.name,
      createdAt: session.createdAt,
      lastUsedAt: DateTime.now(),
      events: session.events,
    );
    await _storage.saveSession(updatedSession);

    _mode = RecorderMode.playback;
    notifyListeners();
  }

  /// Stop playback and return to idle mode
  ///
  /// Clears the playback index and current session.
  void stopPlayback() {
    _currentSession = null;
    _playbackIndex = 0;
    _mode = RecorderMode.idle;
    notifyListeners();
  }

  @override
  FixtureDocument? getRecordedSelection(FixtureCollection fixture) {
    if (_mode != RecorderMode.playback) return null;
    if (_currentSession == null) return null;

    // Check if we've exhausted all events
    if (_playbackIndex >= _currentSession!.events.length) {
      // Auto-stop playback when all events are consumed
      stopPlayback();
      return null;
    }

    // Get the next event in sequence
    final event = _currentSession!.events[_playbackIndex];

    // Verify this event matches the current fixture
    if (event.fixtureKey != fixture.description) {
      return null; // Not the expected fixture, skip
    }

    // Increment playback index for next selection
    _playbackIndex++;
    notifyListeners(); // Notify UI of progress change

    // Strict matching with fallback: try to find the recorded identifier
    try {
      return fixture.items.firstWhere(
        (doc) => doc.identifier == event.selectedIdentifier,
      );
    } catch (e) {
      // Fallback: return null to trigger default behavior
      return null;
    }
  }

  /// List all available sessions
  ///
  /// Returns metadata for all sessions sorted by lastUsedAt then createdAt.
  Future<List<SessionMetadata>> listSessions() => _storage.listSessions();

  /// Delete a session by name
  Future<void> deleteSession(String name) => _storage.deleteSession(name);
}
