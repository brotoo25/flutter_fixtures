/// What a transport adapter does with a request that has no recorded
/// response during replay.
///
/// The replay engine itself only reports the miss (see `SessionReplay`);
/// this policy belongs to the adapters, and each built-in adapter accepts
/// it as a constructor parameter.
enum ReplayMissBehavior {
  /// Let the request continue to the real source (the default). Online, the
  /// app keeps working; offline, the request fails the way it naturally
  /// would.
  forward,

  /// Fail the request. Use this to guarantee a demo never touches the real
  /// source.
  reject,
}
