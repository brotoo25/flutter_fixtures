import 'dart:convert';

import 'recorded_request.dart';

/// One captured request/response pair inside a Recording Session.
///
/// The [request] is the source-agnostic description used for replay
/// matching; the [response] is whatever the capturing adapter needs to
/// reconstruct its native response later — a map of status/headers/body for
/// HTTP, a list of rows for a database — and is opaque to the recorder
/// itself. Adapters own both sides: whoever wrote the response shape is the
/// one who reads it back.
class RecordedInteraction {
  /// What was asked.
  final RecordedRequest request;

  /// What came back, in the capturing adapter's own shape.
  final Object? response;

  /// When this interaction was captured.
  final DateTime recordedAt;

  RecordedInteraction({
    required this.request,
    this.response,
    required this.recordedAt,
  });

  /// Creates an interaction from its session-file JSON representation.
  factory RecordedInteraction.fromJson(Map<String, dynamic> json) {
    return RecordedInteraction(
      request:
          RecordedRequest.fromJson(json['request'] as Map<String, dynamic>),
      response: json['response'],
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  /// Converts this interaction to its session-file JSON representation.
  ///
  /// Values that cannot be JSON-encoded (streams, bytes, arbitrary objects)
  /// are stored as their string representation instead of failing the save.
  Map<String, dynamic> toJson() {
    final requestJson = request.toJson();
    requestJson['payload'] = _jsonSafe(requestJson['payload']);
    return {
      'request': requestJson,
      'response': _jsonSafe(response),
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
