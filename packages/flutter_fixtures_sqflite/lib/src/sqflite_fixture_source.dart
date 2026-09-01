import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'sqflite_query.dart';

/// The sqflite-typed [FixtureSource]: `resolve` takes a [SqfliteQuery] and
/// returns a `FixtureCollection`, or `null` when the source has none.
///
/// The built-in adapter is `SqfliteFileFixtureSource` (fixture files);
/// `FixtureSources` composes several in precedence order, and any
/// [FixtureSource] of this request type plugs in — a database of canned
/// rows, a generator, a test fake.
typedef SqfliteFixtureSource = FixtureSource<SqfliteQuery>;
