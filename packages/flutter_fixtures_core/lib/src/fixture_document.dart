/// Represents a single fixture document
///
/// A FixtureDocument contains information about a specific fixture,
/// including its identifier, description, and data.
///
/// A document carries its payload either inline ([data]) or as a reference
/// to an external file ([dataPath]) — never both. The constructor enforces
/// this, so a fixture that declares both fails at parse time instead of deep
/// inside an adapter.
class FixtureDocument {
  /// A unique identifier for this fixture document
  final String identifier;

  /// A human-readable description of this fixture document.
  ///
  /// For HTTP fixtures the description conventionally starts with a 3-digit
  /// status code (e.g. `"200 Success"`); [statusCode] exposes it parsed.
  final String description;

  /// Whether this is the default option in the collection
  final bool? defaultOption;

  /// The inline data for this fixture, if available
  final dynamic data;

  /// The path to the data file for this fixture, if data is stored externally
  final String? dataPath;

  FixtureDocument({
    required this.identifier,
    required this.description,
    required this.defaultOption,
    this.data,
    String? dataPath,
    // An empty path means "no external file".
  }) : dataPath = (dataPath != null && dataPath.isEmpty) ? null : dataPath {
    if (data != null && this.dataPath != null) {
      throw ArgumentError(
        'A fixture document may provide either data or dataPath, not both '
        '(document "$identifier").',
      );
    }
  }

  /// Creates a document from its fixture-file JSON representation.
  factory FixtureDocument.fromJson(Map<String, dynamic> json) {
    return FixtureDocument(
      identifier: json['identifier'] as String,
      description: json['description'] as String,
      defaultOption: json['default'] as bool? ?? false,
      data: json['data'],
      dataPath: json['dataPath'] as String?,
    );
  }

  /// The HTTP status code encoded at the start of [description], if any.
  ///
  /// Parsed once here so consumers read a typed field instead of slicing
  /// the description string. Returns `null` when the description does not
  /// start with a 3-digit code.
  int? get statusCode {
    final match = RegExp(r'^\s*(\d{3})\b').firstMatch(description);
    return match == null ? null : int.parse(match.group(1)!);
  }
}
