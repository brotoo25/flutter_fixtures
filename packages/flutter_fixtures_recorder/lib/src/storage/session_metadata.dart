/// Lightweight metadata about a recording session
///
/// Used for listing sessions without loading full event data.
class SessionMetadata {
  /// User-provided name for this session
  final String name;

  /// When this session was originally recorded
  final DateTime createdAt;

  /// When this session was last used for playback (null if never played)
  final DateTime? lastUsedAt;

  /// Number of events in this session
  final int eventCount;

  /// Creates session metadata
  SessionMetadata({
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    required this.eventCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMetadata &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          createdAt == other.createdAt &&
          lastUsedAt == other.lastUsedAt &&
          eventCount == other.eventCount;

  @override
  int get hashCode =>
      name.hashCode ^
      createdAt.hashCode ^
      lastUsedAt.hashCode ^
      eventCount.hashCode;

  @override
  String toString() =>
      'SessionMetadata(name: $name, createdAt: $createdAt, lastUsedAt: $lastUsedAt, eventCount: $eventCount)';
}
