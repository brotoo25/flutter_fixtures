library flutter_fixtures_dio;

// The record-and-replay seam types RecorderInterceptor is configured
// with, so a single import covers the adapter and its contract.
export 'package:flutter_fixtures_core/flutter_fixtures_core.dart'
    show
        ForwardToSource,
        RecordedInteraction,
        RecordedRequest,
        RejectRequest,
        Replayed,
        ReplayDecision,
        ReplayMissBehavior,
        TrafficRecorder;

export 'src/dio_interceptor.dart';
export 'src/recorder_interceptor.dart';
