import 'dart:convert';

/// Builds the lookup key used to match a live request against recorded
/// interactions during replay.
///
/// The default is [RecordedInteraction.defaultKey] (method + path + sorted
/// query). Provide a custom builder to ignore volatile parts of a request,
/// such as timestamps or signatures in query parameters.
typedef RequestKeyBuilder = String Function(String method, Uri uri);

/// One captured request/response pair inside a Recording Session.
///
/// An interaction stores what was asked (method, URI, request body) and what
/// came back (status code, headers, body), plus when it was captured. It is
/// transport-agnostic: adapters translate their native request/response types
/// into this shape.
class RecordedInteraction {
  /// The HTTP method (or transport-specific verb) of the request.
  final String method;

  /// The full URI the request was sent to.
  final Uri uri;

  /// The request payload, if any. Informational only — replay matching does
  /// not compare bodies.
  final Object? requestBody;

  /// The status code of the captured response.
  final int statusCode;

  /// The captured response headers.
  final Map<String, List<String>> responseHeaders;

  /// The captured response payload.
  final Object? responseBody;

  /// When this interaction was captured.
  final DateTime recordedAt;

  RecordedInteraction({
    required this.method,
    required this.uri,
    this.requestBody,
    required this.statusCode,
    this.responseHeaders = const {},
    this.responseBody,
    required this.recordedAt,
  });

  /// The default replay lookup key: `METHOD /path?sorted=query`.
  ///
  /// Query parameters are sorted so that replay does not depend on the order
  /// a client happens to serialize them in. The host is intentionally left
  /// out, so sessions recorded against one environment replay against another.
  static String defaultKey(String method, Uri uri) {
    final entries = uri.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final query = entries
        .map((e) => '${e.key}=${(List.of(e.value)..sort()).join(',')}')
        .join('&');
    final path = uri.path.isEmpty ? '/' : uri.path;
    return query.isEmpty
        ? '${method.toUpperCase()} $path'
        : '${method.toUpperCase()} $path?$query';
  }

  /// This interaction's [defaultKey].
  String get requestKey => defaultKey(method, uri);

  /// Creates an interaction from its session-file JSON representation.
  factory RecordedInteraction.fromJson(Map<String, dynamic> json) {
    return RecordedInteraction(
      method: json['method'] as String,
      uri: Uri.parse(json['uri'] as String),
      requestBody: json['requestBody'],
      statusCode: json['statusCode'] as int,
      responseHeaders: (json['responseHeaders'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, List<String>.from(value as List))),
      responseBody: json['responseBody'],
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  /// Converts this interaction to its session-file JSON representation.
  ///
  /// Payloads that cannot be JSON-encoded (streams, bytes, arbitrary objects)
  /// are stored as their string representation instead of failing the save.
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'uri': uri.toString(),
      'requestBody': _jsonSafe(requestBody),
      'statusCode': statusCode,
      'responseHeaders': responseHeaders,
      'responseBody': _jsonSafe(responseBody),
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null) return null;
    try {
      jsonEncode(value);
      return value;
    } catch (_) {
      return value.toString();
    }
  }
}
