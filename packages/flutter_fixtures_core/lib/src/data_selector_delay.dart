/// Named response delays, for simulating network or database latency
/// while serving fixtures.
///
/// A delay is a plain [Duration]; these are the presets. Any other
/// duration works too: `Duration(milliseconds: 1500)`.
abstract final class DataSelectorDelay {
  /// No delay.
  static const Duration instant = Duration.zero;

  /// Fast response (~100ms, comparable to fast 4G/5G).
  static const Duration fast = Duration(milliseconds: 100);

  /// Moderate response (~500ms, comparable to 3G).
  static const Duration moderate = Duration(milliseconds: 500);

  /// Slow response (~2000ms, comparable to 2G/EDGE).
  static const Duration slow = Duration(milliseconds: 2000);
}
