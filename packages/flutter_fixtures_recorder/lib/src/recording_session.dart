import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// A named, ordered capture of request/response traffic.
///
/// A session is what gets saved by the recorder and played back later:
/// an identifier, a human-readable name, when it was recorded, and the
/// captured interactions in the order they happened.
class RecordingSession {
  /// A unique identifier for this session, used as the storage key.
  final String id;

  /// A human-readable name, shown when listing sessions.
  final String name;

  /// When this session was recorded.
  final DateTime recordedAt;

  /// The captured interactions, in capture order.
  final List<RecordedInteraction> interactions;

  RecordingSession({
    required this.id,
    required this.name,
    required this.recordedAt,
    required this.interactions,
  });

  /// Creates a session from its session-file JSON representation.
  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: json['id'] as String,
      name: json['name'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      interactions: (json['interactions'] as List)
          .map((e) => RecordedInteraction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this session to its session-file JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'recordedAt': recordedAt.toIso8601String(),
      'interactions': interactions.map((e) => e.toJson()).toList(),
    };
  }

  /// This session's listing projection.
  RecordingSessionSummary toSummary() {
    return RecordingSessionSummary(
      id: id,
      name: name,
      recordedAt: recordedAt,
      interactionCount: interactions.length,
    );
  }
}

/// The listing projection of a Recording Session: everything a picker
/// needs, none of the recorded payloads.
///
/// Returned by `RecordingSessionStore.list`, so browsing sessions never
/// loads recorded traffic; the full [RecordingSession] is materialized
/// only when a session is replayed.
class RecordingSessionSummary {
  /// The session's unique identifier — pass to `startReplay`/`load`.
  final String id;

  /// The session's human-readable name.
  final String name;

  /// When the session was recorded.
  final DateTime recordedAt;

  /// How many interactions the session holds.
  final int interactionCount;

  RecordingSessionSummary({
    required this.id,
    required this.name,
    required this.recordedAt,
    required this.interactionCount,
  });
}
