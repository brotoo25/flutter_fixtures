library flutter_fixtures_recorder;

// The thin record-and-replay contract lives in core; re-exported here so
// the recorder package remains a self-sufficient import.
export 'package:flutter_fixtures_core/flutter_fixtures_core.dart'
    show
        ForwardToSource,
        RecordedInteraction,
        RecordedRequest,
        RejectRequest,
        Replayed,
        ReplayDecision,
        ReplayMissBehavior,
        RequestKeyBuilder,
        TrafficRecorder;

export 'src/file_session_store.dart';
export 'src/fixture_recorder.dart';
export 'src/recording_session.dart';
export 'src/session_replay.dart';
export 'src/session_store.dart';
export 'src/ui/recorder_toolbar.dart';
export 'src/ui/session_list_sheet.dart';
