import 'recording_event.dart';

/// Represents a complete recording session containing multiple fixture selection events
///
/// A session captures a sequence of user fixture selections that can be replayed later.
class RecordingSession {
  /// User-provided name for this session
  final String name;

  /// When this session was originally recorded
  final DateTime createdAt;

  /// When this session was last used for playback (null if never played)
  final DateTime? lastUsedAt;

  /// The sequence of fixture selections in this session
  final List<RecordingEvent> events;

  /// Creates a new recording session
  RecordingSession({
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    required this.events,
  });

  /// Converts this session to a JSON map
  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
      };

  /// Creates a session from a JSON map
  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      events: (json['events'] as List)
          .map((e) => RecordingEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Creates a copy of this session with updated fields
  RecordingSession copyWith({
    String? name,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    List<RecordingEvent>? events,
  }) {
    return RecordingSession(
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      events: events ?? this.events,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingSession &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          createdAt == other.createdAt &&
          lastUsedAt == other.lastUsedAt &&
          events.length == other.events.length;

  @override
  int get hashCode =>
      name.hashCode ^
      createdAt.hashCode ^
      lastUsedAt.hashCode ^
      events.hashCode;

  @override
  String toString() =>
      'RecordingSession(name: $name, createdAt: $createdAt, lastUsedAt: $lastUsedAt, events: ${events.length} events)';
}
