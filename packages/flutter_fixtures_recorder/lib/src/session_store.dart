import 'recording_session.dart';

/// The persistence seam for Recording Sessions.
///
/// The recorder saves, lists, loads, and deletes sessions exclusively
/// through this interface. The built-in implementations are
/// [MemoryRecordingSessionStore] (runtime-only) and
/// `FileRecordingSessionStore` (JSON files on disk); implement this
/// interface to store sessions anywhere else — a database, a remote
/// service, shared preferences.
///
/// For the common case — files where possible, memory on web — use the
/// `sessionStoreForDirectory` factory instead of choosing per platform.
abstract class RecordingSessionStore {
  /// Persists the session, overwriting any session with the same id.
  ///
  /// Persistent implementations must fail loudly when a recorded response
  /// cannot survive their encoding (for JSON files: anything `jsonEncode`
  /// rejects) — a save-time error beats a corrupted replay.
  Future<void> save(RecordingSession session);

  /// Loads the session with this id, or `null` if it does not exist.
  Future<RecordingSession?> load(String id);

  /// Lists summaries of all stored sessions, most recently recorded first.
  ///
  /// Listing never returns recorded payloads; [load] materializes the
  /// full session.
  Future<List<RecordingSessionSummary>> list();

  /// Deletes the session with this id. Deleting a missing id is a no-op.
  Future<void> delete(String id);
}

/// A runtime-only session store, for tests, web, and ephemeral recordings.
///
/// Sessions never cross an encoding boundary here, so any response value
/// is accepted — which also means this store cannot catch round-trip
/// contract violations the way the file store does.
class MemoryRecordingSessionStore implements RecordingSessionStore {
  final Map<String, RecordingSession> _sessions = {};

  @override
  Future<void> save(RecordingSession session) async {
    _sessions[session.id] = session;
  }

  @override
  Future<RecordingSession?> load(String id) async => _sessions[id];

  @override
  Future<List<RecordingSessionSummary>> list() async {
    final sessions = _sessions.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sessions.map((session) => session.toSummary()).toList();
  }

  @override
  Future<void> delete(String id) async {
    _sessions.remove(id);
  }
}
