import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import 'statement_database_adapter.dart';
import 'sqflite_query.dart';

/// A [DatabaseAdapter] that returns fixture data instead of querying a real database.
///
/// Use this class as a drop-in replacement for [RealDatabaseAdapter] during
/// development and testing. It loads mock data from fixture files.
///
/// ## Usage with DatabaseAdapter
///
/// ```dart
/// class UserRepository {
///   final DatabaseAdapter db;
///   UserRepository(this.db);
///
///   Future<List<User>> getUsers() async {
///     final rows = await db.query('users');
///     return rows.map(User.fromMap).toList();
///   }
/// }
///
/// // In production:
/// final db = RealDatabaseAdapter(await openDatabase('app.db'));
///
/// // In development/testing:
/// final db = FixtureDatabaseAdapter(
///   pipeline: FixturePipeline(
///     source: SqfliteFileFixtureSource(),
///     selector: DataSelectorType.pick,
///   ),
/// );
///
/// final repo = UserRepository(db); // Same code, different data source!
/// ```
///
/// ## Fixture Files
///
/// Create fixture files in `assets/fixtures/database/`:
/// - `query_users.json` for `db.query('users')`
/// - `query_products.json` for `db.query('products')`
/// - `insert_orders.json` for `db.insert('orders', ...)`
class FixtureDatabaseAdapter extends StatementDatabaseAdapter {
  /// The pipeline every statement is served through — source, selection
  /// strategy, picker, memory and delay all live there. Build it once,
  /// next to this adapter: remembered choices live in it.
  final FixturePipeline<SqfliteQuery> pipeline;

  bool _isOpen = true;

  FixtureDatabaseAdapter({required this.pipeline});

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  /// Serves the statement through the pipeline and shapes the payload for
  /// its operation: rows for reads (a list, a `result`-keyed map, or a
  /// single-row map), `insertId` / `affectedRows` for writes (default 1),
  /// nothing for `execute`.
  @override
  Future<Object?> run(SqfliteQuery statement) async {
    final payload = await _payloadFor(statement);
    return switch (statement.operation) {
      SqfliteOperation.query || SqfliteOperation.rawQuery => _rows(payload),
      SqfliteOperation.insert ||
      SqfliteOperation.rawInsert =>
        _intFrom(payload, 'insertId'),
      SqfliteOperation.update ||
      SqfliteOperation.delete ||
      SqfliteOperation.rawUpdate ||
      SqfliteOperation.rawDelete =>
        _intFrom(payload, 'affectedRows'),
      SqfliteOperation.execute => null,
    };
  }

  /// Serves [query] through the pipeline.
  ///
  /// A missing or empty fixture degrades to `null` — callers substitute
  /// their operation's default, so an unfixtured table behaves like an
  /// empty one. A cancelled pick is an explicit user action and is thrown
  /// as [FixtureCancelled].
  Future<Object?> _payloadFor(SqfliteQuery query) async {
    return switch (await pipeline.serve(query)) {
      FixtureServed(:final payload) => payload,
      FixtureCancelled cancelled => throw cancelled,
      FixtureMiss() => null,
    };
  }

  static List<Map<String, dynamic>> _rows(Object? payload) {
    if (payload is List) {
      return payload.cast<Map<String, dynamic>>();
    }
    if (payload is Map) {
      // Fixture files may wrap rows under a top-level result key.
      final rows = payload['result'];
      if (rows is List) {
        return rows.cast<Map<String, dynamic>>();
      }
      // Single row result
      return [payload.cast<String, dynamic>()];
    }
    return [];
  }

  /// The int stored under [key] in a write fixture's payload, defaulting
  /// to 1 when the fixture provides none.
  static int _intFrom(Object? payload, String key) {
    if (payload is Map && payload[key] is int) {
      return payload[key] as int;
    }
    return 1;
  }
}

/// Backwards-compatible alias for [FixtureDatabaseAdapter].
///
/// @Deprecated('Use FixtureDatabaseAdapter instead')
typedef FixtureDatabase = FixtureDatabaseAdapter;
