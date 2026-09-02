import 'package:dio/dio.dart';

import 'dio_interceptor.dart';
import 'recorder_interceptor.dart';

/// Where a Dio response came from, as stamped by this package's
/// interceptors — read it once instead of re-deriving it from header
/// strings and recorder state.
///
/// ```dart
/// switch (ResponseOrigin.of(response)) {
///   case FixtureOrigin(:final document, :final filePath): // served fixture
///   case ReplayOrigin(:final recordedAt):                  // replayed recording
///   case LiveOrigin():                                     // anything else
/// }
/// ```
///
/// Works for error responses too: `ResponseOrigin.of(e.response!)` on a
/// `DioException`. A request that never produced a response — a
/// `FixtureMiss`, a replay rejection — carries its case in
/// `DioException.error` instead.
sealed class ResponseOrigin {
  const ResponseOrigin();

  /// Reads the origin stamped on [response].
  static ResponseOrigin of(Response<dynamic> response) {
    final headers = response.headers;
    final replayedAt = headers.value(RecorderInterceptor.replayedHeader);
    if (replayedAt != null) {
      return ReplayOrigin(recordedAt: DateTime.parse(replayedAt));
    }
    final document = headers.value(FixturesInterceptor.documentHeader);
    if (document != null) {
      return FixtureOrigin(
        document: document,
        filePath: headers.value(FixturesInterceptor.filePathHeader),
      );
    }
    return const LiveOrigin();
  }
}

/// Served by [FixturesInterceptor] from a fixture document.
final class FixtureOrigin extends ResponseOrigin {
  /// The served Fixture Document's identifier.
  final String document;

  /// The document's external payload file, when it has one.
  final String? filePath;

  const FixtureOrigin({required this.document, this.filePath});
}

/// Served by [RecorderInterceptor] from a recording session.
final class ReplayOrigin extends ResponseOrigin {
  /// When the replayed interaction was originally captured.
  final DateTime recordedAt;

  const ReplayOrigin({required this.recordedAt});
}

/// Not stamped by this package: the network, or another interceptor.
final class LiveOrigin extends ResponseOrigin {
  const LiveOrigin();
}
