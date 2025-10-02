import 'fixture_collection.dart';
import 'fixture_document.dart';

/// In-memory store to remember selected fixture options per fixture collection.
///
/// This is intentionally simple (runtime-only) to avoid persistence dependencies.
class FixtureSelectionMemory {
  FixtureSelectionMemory._();

  static final Map<String, String> _rememberedByKey = <String, String>{};

  static String _keyFor(FixtureCollection fixture) => fixture.description;

  /// Returns the remembered document for this fixture collection, if any.
  static FixtureDocument? getRemembered(FixtureCollection fixture) {
    final id = _rememberedByKey[_keyFor(fixture)];
    if (id == null) return null;
    for (final doc in fixture.items) {
      if (doc.identifier == id) return doc;
    }
    return null;
  }

  /// Remembers the given document for the fixture collection.
  static void remember(FixtureCollection fixture, FixtureDocument document) {
    _rememberedByKey[_keyFor(fixture)] = document.identifier;
  }

  /// Clears memory for this fixture collection.
  static void clearFor(FixtureCollection fixture) {
    _rememberedByKey.remove(_keyFor(fixture));
  }

  /// Clears all remembered selections.
  static void clearAll() {
    _rememberedByKey.clear();
  }
}
