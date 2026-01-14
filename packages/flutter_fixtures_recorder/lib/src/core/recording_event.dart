/// Represents a single fixture selection event in a recording session
///
/// Each event captures when a user selects a specific fixture option.
class RecordingEvent {
  /// The key identifying the fixture collection (typically FixtureCollection.description)
  final String fixtureKey;

  /// The identifier of the selected fixture document (FixtureDocument.identifier)
  final String selectedIdentifier;

  /// When this selection occurred
  final DateTime timestamp;

  /// Optional source identifier (e.g., 'dio', 'sqflite', 'custom')
  final String? source;

  /// Creates a new recording event
  RecordingEvent({
    required this.fixtureKey,
    required this.selectedIdentifier,
    required this.timestamp,
    this.source,
  });

  /// Converts this event to a JSON map
  Map<String, dynamic> toJson() => {
        'fixtureKey': fixtureKey,
        'selectedIdentifier': selectedIdentifier,
        'timestamp': timestamp.toIso8601String(),
        if (source != null) 'source': source,
      };

  /// Creates an event from a JSON map
  factory RecordingEvent.fromJson(Map<String, dynamic> json) {
    return RecordingEvent(
      fixtureKey: json['fixtureKey'] as String,
      selectedIdentifier: json['selectedIdentifier'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingEvent &&
          runtimeType == other.runtimeType &&
          fixtureKey == other.fixtureKey &&
          selectedIdentifier == other.selectedIdentifier &&
          timestamp == other.timestamp &&
          source == other.source;

  @override
  int get hashCode =>
      fixtureKey.hashCode ^
      selectedIdentifier.hashCode ^
      timestamp.hashCode ^
      source.hashCode;

  @override
  String toString() =>
      'RecordingEvent(fixtureKey: $fixtureKey, selectedIdentifier: $selectedIdentifier, timestamp: $timestamp, source: $source)';
}
