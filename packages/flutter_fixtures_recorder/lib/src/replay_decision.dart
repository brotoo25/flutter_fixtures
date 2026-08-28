import 'recorded_interaction.dart';

/// The recorder's answer to "how should this request be handled?".
///
/// Returned by `FixtureRecorder.decide`, which owns the whole choreography —
/// mode check, replay lookup, and miss policy — so adapters only translate
/// each case into their native transport:
///
/// ```dart
/// switch (recorder.decide(request, onMiss: onReplayMiss)) {
///   case Replayed(:final interaction): // serve the recorded response
///   case RejectRequest(:final message): // fail with message
///   case ForwardToSource(): // let the real source handle it
/// }
/// ```
sealed class ReplayDecision {}

/// Serve this recorded interaction instead of touching the real source.
final class Replayed extends ReplayDecision {
  /// The recorded interaction to render as a native response.
  final RecordedInteraction interaction;

  Replayed(this.interaction);
}

/// Let the request continue to the real source.
///
/// Returned when the recorder is not replaying, and for replay misses under
/// `ReplayMissBehavior.forward`.
final class ForwardToSource extends ReplayDecision {}

/// Fail the request without touching the real source.
///
/// Returned for replay misses under `ReplayMissBehavior.reject`. The
/// [message] is phrased by the recorder — it knows the session — so every
/// adapter reports the same miss the same way.
final class RejectRequest extends ReplayDecision {
  /// Why the request was rejected.
  final String message;

  RejectRequest(this.message);
}
