/// Represents a SQLite database query for fixture matching
///
/// This class encapsulates the information needed to match a database
/// query to a fixture file. It supports both table-based queries and
/// raw SQL queries.
class SqfliteQuery {
  /// The table name being queried (for table-based queries)
  final String? table;

  /// The raw SQL query (for raw SQL queries)
  final String? sql;

  /// The operation type (query, insert, update, delete, rawQuery)
  final SqfliteOperation operation;

  /// Optional where clause for table-based queries
  final String? where;

  /// Optional columns to select
  final List<String>? columns;

  /// Creates a SqfliteQuery for table-based operations
  const SqfliteQuery.table({
    required this.table,
    required this.operation,
    this.where,
    this.columns,
  }) : sql = null;

  /// Creates a SqfliteQuery for raw SQL operations
  const SqfliteQuery.raw({
    required this.sql,
  })  : table = null,
        operation = SqfliteOperation.rawQuery,
        where = null,
        columns = null;

  /// Generates a fixture file path identifier for this query
  ///
  /// For table queries: {operation}_{table}.json
  /// For raw queries: rawQuery_{hash}.json
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
      return 'rawQuery_$normalized';
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

  /// Raw SQL execution (INSERT/UPDATE/DELETE)
  rawExecute,
}
