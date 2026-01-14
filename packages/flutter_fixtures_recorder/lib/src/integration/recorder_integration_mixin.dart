import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

import '../recorder/fixture_recorder.dart';
import '../storage/json_file_session_storage.dart';
import 'recordable_data_query.dart';

/// Convenience mixin for integrating the recorder into an app
///
/// This mixin provides helper methods for setting up the recorder and
/// wrapping data queries with recording/playback capabilities.
///
/// Example usage:
/// ```dart
/// class MyApp extends StatelessWidget with RecorderIntegrationMixin {
///   @override
///   Widget build(BuildContext context) {
///     final recorder = getOrCreateRecorder();
///     final dio = Dio();
///     dio.interceptors.add(
///       FixturesInterceptor(
///         dataQuery: wrapDataQuery(DioDataQuery(), 'dio'),
///         dataSelectorView: FixturesDialogView(context: context),
///         dataSelector: DataSelectorType.pick(),
///       ),
///     );
///     // ...
///   }
/// }
/// ```
mixin RecorderIntegrationMixin {
  FixtureRecorder? _recorder;

  /// Gets or creates the singleton recorder instance
  ///
  /// Creates a new recorder with JSON file storage if one doesn't exist.
  FixtureRecorder getOrCreateRecorder() {
    _recorder ??= FixtureRecorder(
      storage: JsonFileSessionStorage(),
    );
    return _recorder!;
  }

  /// Wraps a data query with recording/playback capabilities
  ///
  /// The [dataQuery] is the original query to wrap, and [source] identifies
  /// where selections come from (e.g., 'dio', 'sqflite').
  DataQuery<I, O> wrapDataQuery<I, O>(
    DataQuery<I, O> dataQuery,
    String source,
  ) {
    return RecordableDataQuery(
      delegate: dataQuery,
      recorder: getOrCreateRecorder(),
      source: source,
    );
  }
}
