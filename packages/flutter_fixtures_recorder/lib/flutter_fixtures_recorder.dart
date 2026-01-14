/// Recording and playback for Flutter Fixtures user selections
///
/// This library provides tools for recording fixture selections during app
/// usage and playing them back in future sessions. This is useful for:
/// - Creating repeatable test scenarios
/// - Debugging specific flows
/// - Demonstrating features with consistent data
///
/// ## Getting Started
///
/// 1. Create a [FixtureRecorder] instance:
/// ```dart
/// final recorder = FixtureRecorder(
///   storage: JsonFileSessionStorage(),
/// );
/// ```
///
/// 2. Wrap your data queries:
/// ```dart
/// final dioDataQuery = RecordableDataQuery(
///   delegate: DioDataQuery(),
///   recorder: recorder,
///   source: 'dio',
/// );
/// ```
///
/// 3. Add the overlay widget to your app:
/// ```dart
/// Stack(
///   children: [
///     YourApp(),
///     RecorderOverlayWidget(
///       recorder: recorder,
///       isMockMode: true,
///     ),
///   ],
/// );
/// ```
///
/// ## Recording Sessions
///
/// 1. Tap the blue FAB button
/// 2. Select "Start Recording"
/// 3. Interact with your app (select fixtures)
/// 4. Tap the red FAB button
/// 5. Enter a name for the session
/// 6. Tap "Save"
///
/// ## Playing Back Sessions
///
/// 1. Tap the blue FAB button
/// 2. Select a session from the list
/// 3. Interact with your app - fixtures will be auto-selected
/// 4. Tap the green FAB button to stop playback
library flutter_fixtures_recorder;

// Core
export 'src/core/recording_event.dart';
export 'src/core/recording_session.dart';
export 'src/core/recorder_mode.dart';
export 'src/core/selection_event_notifier.dart';

// Recorder
export 'src/recorder/fixture_recorder.dart';
export 'src/recorder/playback_data_selector.dart';

// Storage
export 'src/storage/session_storage.dart';
export 'src/storage/json_file_session_storage.dart';
export 'src/storage/session_metadata.dart';

// Integration
export 'src/integration/recordable_data_query.dart';
export 'src/integration/recorder_integration_mixin.dart';

// UI
export 'src/ui/recorder_overlay_widget.dart';
export 'src/ui/session_list_widget.dart';
export 'src/ui/recording_status_indicator.dart';
