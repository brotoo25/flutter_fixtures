import 'dart:convert';
import 'dart:io';

import 'recording_session.dart';
import 'session_store.dart';

/// The persistent store for the current platform: JSON files under the
/// directory [directory] resolves to.
///
/// On web (no file system) this returns a [MemoryRecordingSessionStore]
/// instead, so callers never branch on platform:
///
/// ```dart
/// final recorder = FixtureRecorder(
///   store: sessionStoreForDirectory(() async =>
///       '${(await getApplicationDocumentsDirectory()).path}/fixture_recordings'),
/// );
/// ```
///
/// [directory] is invoked lazily on first use, so the recorder can be
/// constructed synchronously.
RecordingSessionStore sessionStoreForDirectory(
  Future<String> Function() directory,
) {
  return FileRecordingSessionStore.deferred(directory);
}

/// A session store that keeps each session as a JSON file in a directory.
///
/// The directory is created on first save. Callers provide the path — or a
/// deferred path via [FileRecordingSessionStore.deferred], resolved lazily
/// on first use (pair it with `path_provider` without an async
/// construction dance).
///
/// Saving fails loudly when a recorded response cannot be JSON-encoded:
/// the error names the session, so a round-trip contract violation
/// surfaces at record time instead of corrupting a later replay.
///
/// Not available on web; `sessionStoreForDirectory` falls back to
/// [MemoryRecordingSessionStore] there.
class FileRecordingSessionStore implements RecordingSessionStore {
  final Future<String> Function() _directoryPath;
  Future<String>? _resolved;

  FileRecordingSessionStore(String directoryPath)
      : _directoryPath = ((() async => directoryPath));

  /// Resolves the directory lazily, on first use.
  FileRecordingSessionStore.deferred(Future<String> Function() directoryPath)
      : _directoryPath = directoryPath;

  Future<String> get _dir => _resolved ??= _directoryPath();

  Future<File> _fileFor(String id) async => File('${await _dir}/$id.json');

  @override
  Future<void> save(RecordingSession session) async {
    final String encoded;
    try {
      encoded = jsonEncode(session.toJson());
    } on JsonUnsupportedObjectError catch (e) {
      throw StateError(
        'Recording session "${session.name}" cannot be persisted: a '
        'recorded value of type ${e.unsupportedObject.runtimeType} is not '
        'JSON-encodable. Adapters must record responses that survive a '
        'JSON round-trip.',
      );
    }
    await Directory(await _dir).create(recursive: true);
    await (await _fileFor(session.id)).writeAsString(encoded);
  }

  @override
  Future<RecordingSession?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    return RecordingSession.fromJson(
        _decode(await file.readAsString(), file.path));
  }

  @override
  Future<List<RecordingSessionSummary>> list() async {
    final dir = Directory(await _dir);
    if (!await dir.exists()) return [];
    final summaries = <RecordingSessionSummary>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        // Project the summary straight from JSON — listing never builds
        // the recorded interactions.
        final json = _decode(await entry.readAsString(), entry.path);
        summaries.add(RecordingSessionSummary(
          id: json['id'] as String,
          name: json['name'] as String,
          recordedAt: DateTime.parse(json['recordedAt'] as String),
          interactionCount: (json['interactions'] as List).length,
        ));
      }
    }
    summaries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return summaries;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  // A session file that exists but cannot be parsed fails loudly rather
  // than silently disappearing from the list.
  Map<String, dynamic> _decode(String content, String path) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Malformed recording session file "$path": $e');
    }
  }
}
