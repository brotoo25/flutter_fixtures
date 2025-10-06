/// Represents a delay duration for data selection operations
///
/// This class provides predefined delay durations that can be used to simulate
/// various network conditions (similar to instant, fast 4G, slow 3G, and offline scenarios)
/// or for any other purpose where controlled delays are needed.
///
/// The delays are intentionally named generically to allow usage in non-network
/// contexts, though they are calibrated to represent typical network latencies:
/// - [instant]: No delay (comparable to cached/local data)
/// - [fast]: ~100ms delay (comparable to fast 4G/5G connections)
/// - [moderate]: ~500ms delay (comparable to average 3G connections)
/// - [slow]: ~2000ms delay (comparable to slow 2G/edge connections)
class DataSelectorDelay {
  /// The delay duration in milliseconds
  final int milliseconds;

  const DataSelectorDelay._(this.milliseconds);

  /// No delay - returns immediately
  ///
  /// Comparable to: Cached data or local storage access
  static const instant = DataSelectorDelay._(0);

  /// Fast response delay (~100ms)
  ///
  /// Comparable to: Fast 4G/5G network connections
  static const fast = DataSelectorDelay._(100);

  /// Moderate response delay (~500ms)
  ///
  /// Comparable to: Average 3G network connections
  static const moderate = DataSelectorDelay._(500);

  /// Slow response delay (~2000ms)
  ///
  /// Comparable to: Slow 2G/EDGE network connections
  static const slow = DataSelectorDelay._(2000);

  /// Create a custom delay with a specific duration
  ///
  /// [milliseconds] must be non-negative
  factory DataSelectorDelay.custom(int milliseconds) {
    if (milliseconds < 0) {
      throw ArgumentError.value(
        milliseconds,
        'milliseconds',
        'Delay duration must be non-negative',
      );
    }
    return DataSelectorDelay._(milliseconds);
  }

  /// Returns a [Duration] object representing this delay
  Duration get duration => Duration(milliseconds: milliseconds);

  /// Applies this delay by waiting for the specified duration
  ///
  /// Returns a [Future] that completes after the delay period
  Future<void> apply() => Future.delayed(duration);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSelectorDelay &&
          runtimeType == other.runtimeType &&
          milliseconds == other.milliseconds;

  @override
  int get hashCode => milliseconds.hashCode;

  @override
  String toString() => 'DataSelectorDelay(${milliseconds}ms)';
}
