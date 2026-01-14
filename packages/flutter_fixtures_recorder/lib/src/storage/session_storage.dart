import '../core/recording_session.dart';
import 'session_metadata.dart';

/// Abstract interface for storing and retrieving recording sessions
///
/// Implementations can use different storage backends (filesystem, database,
/// cloud storage, etc.). The default implementation uses JSON files on the
/// local filesystem.
abstract class SessionStorage {
  /// Save a recording session
  ///
  /// If a session with the same name already exists, it will be overwritten.
  Future<void> saveSession(RecordingSession session);

  /// Load a recording session by name
  ///
  /// Returns null if no session with the given name exists.
  Future<RecordingSession?> loadSession(String name);

  /// List all available sessions
  ///
  /// Returns metadata for all sessions, sorted by lastUsedAt (descending)
  /// then createdAt (descending). This avoids loading full session data
  /// when just displaying a list.
  Future<List<SessionMetadata>> listSessions();

  /// Delete a session by name
  ///
  /// Does nothing if the session doesn't exist.
  Future<void> deleteSession(String name);
}
