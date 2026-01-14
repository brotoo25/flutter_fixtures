import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/recording_session.dart';
import 'session_metadata.dart';
import 'session_storage.dart';

/// Stores recording sessions as JSON files in the app documents directory
///
/// Each session is saved as a separate JSON file named `session_<name>.json`
/// in the `flutter_fixtures_sessions` subdirectory.
class JsonFileSessionStorage implements SessionStorage {
  /// Optional custom directory for storing sessions
  ///
  /// If null, uses the app documents directory.
  final Directory? customDirectory;

  /// Creates a JSON file storage instance
  ///
  /// By default, sessions are stored in `<app_documents>/flutter_fixtures_sessions/`.
  /// Provide [customDirectory] to use a different location.
  JsonFileSessionStorage({this.customDirectory});

  /// Gets the directory where session files are stored
  Future<Directory> get _sessionsDirectory async {
    if (customDirectory != null) return customDirectory!;

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/flutter_fixtures_sessions');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Generates a safe filename for a session name
  ///
  /// Replaces invalid filename characters with underscores.
  String _filenameForSession(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'session_$sanitized.json';
  }

  @override
  Future<void> saveSession(RecordingSession session) async {
    final dir = await _sessionsDirectory;
    final file = File('${dir.path}/${_filenameForSession(session.name)}');
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  @override
  Future<RecordingSession?> loadSession(String name) async {
    try {
      final dir = await _sessionsDirectory;
      final file = File('${dir.path}/${_filenameForSession(name)}');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      return RecordingSession.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } catch (e) {
      // Return null if file is corrupted or unreadable
      return null;
    }
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    try {
      final dir = await _sessionsDirectory;
      if (!await dir.exists()) return [];

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));

      final metadataList = <SessionMetadata>[];
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          metadataList.add(
            SessionMetadata(
              name: json['name'] as String,
              createdAt: DateTime.parse(json['createdAt'] as String),
              lastUsedAt: json['lastUsedAt'] != null
                  ? DateTime.parse(json['lastUsedAt'] as String)
                  : null,
              eventCount: (json['events'] as List).length,
            ),
          );
        } catch (e) {
          // Skip malformed files
          continue;
        }
      }

      // Sort by lastUsedAt descending, then createdAt descending
      metadataList.sort((a, b) {
        final aDate = a.lastUsedAt ?? a.createdAt;
        final bDate = b.lastUsedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      return metadataList;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteSession(String name) async {
    try {
      final dir = await _sessionsDirectory;
      final file = File('${dir.path}/${_filenameForSession(name)}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors if file doesn't exist or can't be deleted
    }
  }
}
