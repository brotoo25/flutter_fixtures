/// Defines the current mode of the recorder
///
/// The recorder can be in one of three states:
/// - [idle]: Not recording or playing back
/// - [recording]: Currently recording fixture selections
/// - [playback]: Playing back a recorded session
enum RecorderMode {
  /// Not recording or playing back
  idle,

  /// Currently recording fixture selections
  recording,

  /// Playing back a recorded session
  playback,
}
