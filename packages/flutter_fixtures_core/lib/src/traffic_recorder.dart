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
abstract class TrafficRecorder {
  /// Decides how a request should be handled: serve a recorded response,
  /// let the request continue to the real source, or fail it.
  ///
  /// [onMiss] is the adapter's policy for requests with no recorded
  /// response during replay; interpreting it is the recorder's job.
  ReplayDecision decide(
    RecordedRequest request, {
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
  });

  /// Captures one interaction. Must be a no-op unless the recorder is
  /// capturing, so adapters can call it unconditionally.
  void record(RecordedInteraction interaction);
}
