/// Represents a single fixture document
///
/// A FixtureDocument contains information about a specific fixture,
/// including its identifier, description, and data.
class FixtureDocument {
  /// A unique identifier for this fixture document
  final String identifier;

  /// A description of this fixture document (often includes status code)
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
    this.dataPath,
  });
}
