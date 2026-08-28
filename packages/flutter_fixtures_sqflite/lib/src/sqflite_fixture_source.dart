import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'sqflite_query.dart';

/// Seam for providing sqflite fixtures.
///
/// Implementations turn a database query into a [FixtureCollection] — the
/// file-backed [SqfliteDataQuery] is the built-in adapter; tests substitute
/// in-memory fakes.
abstract class SqfliteFixtureSource {
  /// Returns the fixture collection for [query], or `null` when this source
  /// has no fixture for it.
  Future<FixtureCollection?> find(SqfliteQuery query);

  /// Returns a document's payload, or `null` when the document carries none.
  Future<Object?> data(FixtureDocument document);
}
