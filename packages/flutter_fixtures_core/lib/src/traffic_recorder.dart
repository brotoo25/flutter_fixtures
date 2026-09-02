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
