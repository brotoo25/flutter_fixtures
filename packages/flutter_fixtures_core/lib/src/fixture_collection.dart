import 'fixture_document.dart';

/// Represents a collection of fixture documents
///
/// A FixtureCollection contains a description and a list of FixtureDocument objects
/// that represent different possible responses or data states.
class FixtureCollection {
  /// A description of the fixture collection
  final String description;

  /// The list of fixture documents in this collection
  final List<FixtureDocument> items;

  FixtureCollection({required this.description, required this.items});

  /// Creates a collection from its fixture-file JSON representation.
  ///
  /// The wire format is `{"description": ..., "values": [...]}`; each entry
  /// of `values` is parsed by [FixtureDocument.fromJson].
  factory FixtureCollection.fromJson(Map<String, dynamic> json) {
    return FixtureCollection(
      description: json['description'] as String? ?? '',
      items: (json['values'] as List)
          .map((option) =>
              FixtureDocument.fromJson((option as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
