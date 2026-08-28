/// Builds the lookup key used to match a live request against recorded
/// interactions during replay.
///
/// The default is [RecordedRequest.defaultKey]. Provide a custom builder to
/// ignore volatile parts of a request — timestamps or signatures in an HTTP
/// query, for example.
typedef RequestKeyBuilder = String Function(RecordedRequest request);

/// A source-agnostic description of one request.
///
/// Every data source describes its requests in the same three-part shape,
/// which is what lets one recorder capture and replay traffic from any of
/// them:
///
/// - [source] names the kind of data source (`'http'`, `'sqlite'`, a custom
///   name), keeping different sources from colliding in one session.
/// - [operation] is the verb within that source: an HTTP method, a database
///   operation like `query` or `insert`.
/// - [target] is the normalized subject of the operation: an HTTP path with
///   sorted query, a SQL statement with its arguments. Adapters own the
///   normalization — the same logical request must always produce the same
///   target.
///
/// [payload] carries informational request detail (an HTTP body, inserted
/// values); it does not participate in replay matching.
class RecordedRequest {
  /// The kind of data source this request belongs to.
  final String source;

  /// The verb within the source.
  final String operation;

  /// The normalized subject of the operation.
  final String target;

  /// Informational request detail; not used for matching.
  final Object? payload;

  RecordedRequest({
    required this.source,
    required this.operation,
    required this.target,
    this.payload,
  });

  /// The default replay lookup key: `source operation target`.
  static String defaultKey(RecordedRequest request) {
    return '${request.source} ${request.operation} ${request.target}';
  }

  /// Creates a request from its session-file JSON representation.
  factory RecordedRequest.fromJson(Map<String, dynamic> json) {
    return RecordedRequest(
      source: json['source'] as String,
      operation: json['operation'] as String,
      target: json['target'] as String,
      payload: json['payload'],
    );
  }

  /// Converts this request to its session-file JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'operation': operation,
      'target': target,
      'payload': payload,
    };
  }
}
