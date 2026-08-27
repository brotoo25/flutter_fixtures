import 'dart:convert';
import 'dart:io';

import 'recording_session.dart';
import 'session_store.dart';

/// A session store that keeps each session as a JSON file in a directory.
///
/// The directory is created on first save. Callers provide the path — pair
/// it with `path_provider`'s application documents directory to persist
/// sessions across app restarts:
///
/// ```dart
/// final dir = await getApplicationDocumentsDirectory();
/// final store = FileRecordingSessionStore('${dir.path}/fixture_recordings');
/// ```
///
/// Not available on web; use [MemoryRecordingSessionStore] or a custom
/// [RecordingSessionStore] there.
class FileRecordingSessionStore implements RecordingSessionStore {
  /// The directory session files are stored in.
  final String directoryPath;

  FileRecordingSessionStore(this.directoryPath);

  File _fileFor(String id) => File('$directoryPath/$id.json');

  @override
  Future<void> save(RecordingSession session) async {
    await Directory(directoryPath).create(recursive: true);
    await _fileFor(session.id).writeAsString(jsonEncode(session.toJson()));
  }

  @override
  Future<RecordingSession?> load(String id) async {
    final file = _fileFor(id);
    if (!await file.exists()) return null;
    return _decode(await file.readAsString(), file.path);
  }

  @override
  Future<List<RecordingSession>> list() async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];
    final sessions = <RecordingSession>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        sessions.add(_decode(await entry.readAsString(), entry.path));
      }
    }
    sessions.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sessions;
  }

  @override
  Future<void> delete(String id) async {
    final file = _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  // A session file that exists but cannot be parsed fails loudly rather
  // than silently disappearing from the list.
  RecordingSession _decode(String content, String path) {
    try {
      return RecordingSession.fromJson(
          jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      throw FormatException('Malformed recording session file "$path": $e');
    }
  }
}
