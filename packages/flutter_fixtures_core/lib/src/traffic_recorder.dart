import 'recorded_interaction.dart';
import 'recorded_request.dart';
import 'replay_decision.dart';
import 'replay_miss_behavior.dart';

/// The thin record-and-replay seam between source adapters and a recorder.
///
/// Transport packages capture and replay traffic exclusively through this
/// interface: describe a request as a [RecordedRequest], ask [decide] how
/// to handle it, render the returned [ReplayDecision] in native types, and
/// feed live results back through [record]. All the heavy lifting — mode
/// machine, sessions, persistence, ordered playback, UI — belongs to the
/// implementation (`FixtureRecorder` in `flutter_fixtures_recorder`); this
/// contract is deliberately just the two calls an adapter needs, so
/// adapters never inspect recorder state.
///
/// Both calls take *builder functions* rather than built values: the
/// recorder invokes them only when its mode requires them, so while it is
/// idle no request descriptions are built, no payloads are copied, and no
/// encoding runs — idle traffic is genuinely free.
abstract class TrafficRecorder {
  /// Decides how a request should be handled: serve a recorded response,
  /// let the request continue to the real source, or fail it.
  ///
  /// [request] is invoked only while replaying. [onMiss] is the adapter's
  /// policy for requests with no recorded response during replay;
  /// interpreting it is the recorder's job.
  ReplayDecision decide(
    RecordedRequest Function() request, {
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
  });

  /// Captures one interaction. [capture] is invoked only while recording,
  /// so adapters can call this unconditionally at zero idle cost.
  ///
  /// The captured interaction's `response` is read back by the same
  /// adapter that wrote it, and must survive a JSON encode/decode round
  /// trip when sessions are persisted — see [RecordedInteraction].
  void record(RecordedInteraction Function() capture);
}

/// The source names the built-in adapters use for [RecordedRequest.source]
/// — owned by core so sessions from every adapter agree on them.
abstract final class RecordedSources {
  /// HTTP traffic (`RecorderInterceptor`).
  static const String http = 'http';

  /// sqflite traffic (`RecorderDatabaseAdapter`).
  static const String sqlite = 'sqlite';
}

/// The record-and-replay choreography for call/return sources, owned once.
///
/// A source whose request is one call that returns one result — a
/// database statement, a cache lookup, a platform channel — has exactly
/// one correct way to use [TrafficRecorder]: describe lazily, ask
/// [TrafficRecorder.decide], serve a replay, throw a rejection, or run the
/// live call and then record its result. [run] is that choreography, so an
/// adapter supplies only the description, the live call, and (optionally)
/// how a recorded response decodes back to its native type:
///
/// ```dart
/// Future<List<Row>> query(String sql) => recorder.run(
///       describe: () => RecordedRequest(
///         source: 'sqlite', operation: 'query', target: sql),
///       live: () => database.query(sql),
///       decode: Row.fromRecorded,
///     );
/// ```
///
/// Transports that split request and response stages (Dio's interceptor
/// chain) render the decision by hand instead — see `RecorderInterceptor`.
extension TrafficRecorderRun on TrafficRecorder {
  /// Serves one call/return request through the recorder.
  ///
  /// [describe] is invoked only when the recorder's mode needs it. On
  /// [ForwardToSource], [live] runs and its result is recorded (only while
  /// recording) and returned. On [Replayed], the recorded response is
  /// passed through [decode] (identity cast by default). On
  /// [RejectRequest], [reject] turns the recorder's message into the error
  /// to throw — a [StateError] by default.
  Future<T> run<T>({
    required RecordedRequest Function() describe,
    required Future<T> Function() live,
    T Function(Object? recorded)? decode,
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
    Object Function(String message) reject = StateError.new,
  }) async {
    switch (decide(describe, onMiss: onMiss)) {
      case Replayed(:final interaction):
        final recorded = interaction.response;
        return decode == null ? recorded as T : decode(recorded);
      case RejectRequest(:final message):
        throw reject(message);
      case ForwardToSource():
        final result = await live();
        record(() => RecordedInteraction(
              request: describe(),
              response: result,
              recordedAt: DateTime.now(),
            ));
        return result;
    }
  }
}
