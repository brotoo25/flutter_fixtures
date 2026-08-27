import 'recording_session.dart';
import 'session_store.dart';

/// Web stand-in for the IO-backed file store.
///
/// File storage is not available on web; construct a
/// [MemoryRecordingSessionStore] or a custom [RecordingSessionStore] instead.
class FileRecordingSessionStore implements RecordingSessionStore {
  final String directoryPath;

  FileRecordingSessionStore(this.directoryPath) {
    throw UnsupportedError(
      'FileRecordingSessionStore is not supported on web. '
      'Use MemoryRecordingSessionStore or a custom RecordingSessionStore.',
    );
  }

  @override
  Future<void> save(RecordingSession session) => throw UnsupportedError('');

  @override
  Future<RecordingSession?> load(String id) => throw UnsupportedError('');

  @override
  Future<List<RecordingSession>> list() => throw UnsupportedError('');

  @override
  Future<void> delete(String id) => throw UnsupportedError('');
}
