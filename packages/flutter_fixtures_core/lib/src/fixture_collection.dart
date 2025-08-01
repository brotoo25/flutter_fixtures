import 'package:flutter_fixtures_core/src/fixture_document.dart';

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
}
