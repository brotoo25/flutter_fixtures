import 'recording_session.dart';

/// The persistence seam for Recording Sessions.
///
/// The recorder saves, lists, loads, and deletes sessions exclusively
/// through this interface. The built-in implementations are
/// [MemoryRecordingSessionStore] (runtime-only) and
/// `FileRecordingSessionStore` (JSON files on disk); implement this
/// interface to store sessions anywhere else — a database, a remote
/// service, shared preferences.
abstract class RecordingSessionStore {
  /// Persists the session, overwriting any session with the same id.
  Future<void> save(RecordingSession session);

  /// Loads the session with this id, or `null` if it does not exist.
  Future<RecordingSession?> load(String id);

  /// Lists all stored sessions, most recently recorded first.
  Future<List<RecordingSession>> list();

  /// Deletes the session with this id. Deleting a missing id is a no-op.
  Future<void> delete(String id);
}

/// A runtime-only session store, for tests and ephemeral recordings.
class MemoryRecordingSessionStore implements RecordingSessionStore {
  final Map<String, RecordingSession> _sessions = {};

  @override
  Future<void> save(RecordingSession session) async {
    _sessions[session.id] = session;
  }

  @override
  Future<RecordingSession?> load(String id) async => _sessions[id];

  @override
  Future<List<RecordingSession>> list() async {
    final sessions = _sessions.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sessions;
  }

  @override
  Future<void> delete(String id) async {
    _sessions.remove(id);
  }
}
