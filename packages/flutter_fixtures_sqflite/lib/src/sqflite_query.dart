import 'dart:convert';

/// The full identity of one SQLite statement.
///
/// One model answers "is this the same logical statement?" for the whole
/// package, carrying every field a `DatabaseAdapter` operation takes. Two
/// projections render it for the two consumers:
///
/// - [fixtureCandidates] — the *deliberately lossy* fixture-file names
///   (arguments and modifiers ignored, so one fixture serves a family of
///   statements);
/// - [recordingTarget] — the *total* canonical JSON used as the record &
///   replay match key (arguments included, so `id = ? [1]` and
///   `id = ? [2]` are different recordings).
class SqfliteQuery {
  /// The table name being queried (for table-based queries)
  final String? table;

  /// The raw SQL query (for raw SQL queries)
  final String? sql;

  /// The operation type
  final SqfliteOperation operation;

  /// Optional where clause for table-based queries
  final String? where;

  /// Optional columns to select
  final List<String>? columns;

  /// Positional arguments for [where] or [sql]
  final List<Object?>? arguments;

  /// Row values for insert/update operations
  final Map<String, Object?>? values;

  /// Whether the query is DISTINCT
  final bool? distinct;

  /// Optional GROUP BY clause
  final String? groupBy;

  /// Optional HAVING clause
  final String? having;

  /// Optional ORDER BY clause
  final String? orderBy;

  /// Optional LIMIT
  final int? limit;

  /// Optional OFFSET
  final int? offset;

  /// sqflite's nullColumnHack, for inserts
  final String? nullColumnHack;

  /// The conflict algorithm's name, for insert/update
  final String? conflictAlgorithm;

  /// Creates a SqfliteQuery for table-based operations
  const SqfliteQuery.table({
    required this.table,
    required this.operation,
    this.where,
    this.columns,
    this.arguments,
    this.values,
    this.distinct,
    this.groupBy,
    this.having,
    this.orderBy,
    this.limit,
    this.offset,
    this.nullColumnHack,
    this.conflictAlgorithm,
  }) : sql = null;

  /// Creates a SqfliteQuery for raw SQL operations
  const SqfliteQuery.raw({
    required this.sql,
    this.operation = SqfliteOperation.rawQuery,
    this.arguments,
  })  : table = null,
        where = null,
        columns = null,
        values = null,
        distinct = null,
        groupBy = null,
        having = null,
        orderBy = null,
        limit = null,
        offset = null,
        nullColumnHack = null,
        conflictAlgorithm = null;

  /// Generates a fixture file path identifier for this query
  ///
  /// For table queries: {operation}_{table}.json
  /// For raw queries: {operation}_{normalized sql}.json
  String get fixtureIdentifier {
    if (sql != null) {
      // For raw queries, create a simplified identifier from the SQL
      var normalized = sql!
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      // Truncate to max 50 chars
      if (normalized.length > 50) {
        normalized = normalized.substring(0, 50);
      }
      return '${operation.name}_$normalized';
    }

    final buffer = StringBuffer()
      ..write(operation.name)
      ..write('_')
      ..write(table);

    if (where != null && where!.isNotEmpty) {
      final normalizedWhere = where!
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      buffer
        ..write('_')
        ..write(normalizedWhere);
    }

    return buffer.toString();
  }

  /// The ordered fixture-file candidates for this query, most specific
  /// first: the full identifier, then — for table queries with a where
  /// clause — the bare `{operation}_{table}` fixture as a fallback.
  List<String> get fixtureCandidates => [
        '$fixtureIdentifier.json',
        if (table != null && where != null) '${operation.name}_$table.json',
      ];

  /// The total, canonical rendering of this statement for record & replay
  /// matching: JSON with a fixed field order and nulls omitted, so the
  /// same logical statement always produces the same target and any
  /// differing argument produces a different one.
  String get recordingTarget {
    final fields = <String, Object?>{
      'table': table,
      'sql': sql,
      'distinct': distinct,
      'columns': columns,
      'where': where,
      'arguments': arguments,
      'values': values,
      'groupBy': groupBy,
      'having': having,
      'orderBy': orderBy,
      'limit': limit,
      'offset': offset,
      'nullColumnHack': nullColumnHack,
      'conflictAlgorithm': conflictAlgorithm,
    }..removeWhere((_, value) => value == null);
    return jsonEncode(fields);
  }

  @override
  String toString() =>
      'SqfliteQuery(table: $table, sql: $sql, operation: $operation, where: $where)';
}

/// Supported SQLite operations
enum SqfliteOperation {
  /// SELECT query on a table
  query,

  /// INSERT operation
  insert,

  /// UPDATE operation
  update,

  /// DELETE operation
  delete,

  /// Raw SQL query
  rawQuery,

  /// Raw SQL INSERT statement
  rawInsert,

  /// Raw SQL UPDATE statement
  rawUpdate,

  /// Raw SQL DELETE statement
  rawDelete,

  /// Raw SQL statement (DDL etc.)
  execute,
}
