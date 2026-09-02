import 'recording_session.dart';
import 'session_store.dart';

/// Web variant: no file system, so persistent-where-possible resolves to
/// a [MemoryRecordingSessionStore] — recordings live for the app's
/// lifetime. The [directory] callback is never invoked.
RecordingSessionStore sessionStoreForDirectory(
  Future<String> Function() directory,
) {
  return MemoryRecordingSessionStore();
}

/// Web stand-in for the IO-backed file store.
///
/// File storage is not available on web; use `sessionStoreForDirectory`
/// (which falls back to memory there), a [MemoryRecordingSessionStore],
/// or a custom [RecordingSessionStore].
class FileRecordingSessionStore implements RecordingSessionStore {
  static Never _unsupported() => throw UnsupportedError(
        'FileRecordingSessionStore is not supported on web. Use '
        'sessionStoreForDirectory (memory fallback), '
        'MemoryRecordingSessionStore, or a custom RecordingSessionStore.',
      );

  FileRecordingSessionStore(String directoryPath) {
    _unsupported();
  }

  FileRecordingSessionStore.deferred(Future<String> Function() directoryPath) {
    _unsupported();
  }

  @override
  Future<void> save(RecordingSession session) => _unsupported();

  @override
  Future<RecordingSession?> load(String id) => _unsupported();

  @override
  Future<List<RecordingSessionSummary>> list() => _unsupported();

  @override
  Future<void> delete(String id) => _unsupported();
}
