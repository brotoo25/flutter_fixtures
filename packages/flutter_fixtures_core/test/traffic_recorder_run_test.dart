import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted recorder: answers decide() with a canned decision and keeps
/// what record() captured, so run() is tested against the seam alone.
class _ScriptedRecorder implements TrafficRecorder {
  _ScriptedRecorder(this.decision, {this.recording = true});

  final ReplayDecision decision;
  final bool recording;
  final List<RecordedInteraction> captured = [];
  int describeCalls = 0;

  @override
  ReplayDecision decide(
    RecordedRequest Function() request, {
    ReplayMissBehavior onMiss = ReplayMissBehavior.forward,
  }) {
    if (decision is! ForwardToSource) {
      describeCalls++;
      request();
    }
    return decision;
  }

  @override
  void record(RecordedInteraction Function() capture) {
    if (recording) captured.add(capture());
  }
}

RecordedRequest _describe() =>
    RecordedRequest(source: 'cache', operation: 'read', target: 'prefs');

void main() {
  group('TrafficRecorder.run', () {
    test('forwards to the live call and records its result', () async {
      final recorder = _ScriptedRecorder(ForwardToSource());

      final result = await recorder.run<String>(
        describe: _describe,
        live: () async => 'live value',
      );

      expect(result, 'live value');
      expect(recorder.captured.single.response, 'live value');
      expect(recorder.captured.single.request.target, 'prefs');
    });

    test('does not build a description or record while idle', () async {
      final recorder = _ScriptedRecorder(ForwardToSource(), recording: false);
      var described = false;

      await recorder.run<int>(
        describe: () {
          described = true;
          return _describe();
        },
        live: () async => 1,
      );

      expect(described, isFalse);
      expect(recorder.captured, isEmpty);
    });

    test('serves a replayed response through decode', () async {
      final recorder = _ScriptedRecorder(Replayed(RecordedInteraction(
        request: _describe(),
        response: '42',
        recordedAt: DateTime(2026, 9, 2),
      )));
      var liveCalls = 0;

      final result = await recorder.run<int>(
        describe: _describe,
        live: () async {
          liveCalls++;
          return 0;
        },
        decode: (recorded) => int.parse(recorded as String),
      );

      expect(result, 42);
      expect(liveCalls, 0);
      expect(recorder.captured, isEmpty);
    });

    test('a replayed response defaults to an identity cast', () async {
      final recorder = _ScriptedRecorder(Replayed(RecordedInteraction(
        request: _describe(),
        response: 7,
        recordedAt: DateTime(2026, 9, 2),
      )));

      expect(
        await recorder.run<int>(describe: _describe, live: () async => 0),
        7,
      );
    });

    test('a rejection throws the recorder\'s message as a StateError',
        () async {
      final recorder = _ScriptedRecorder(RejectRequest('no recording'));

      await expectLater(
        recorder.run<int>(describe: _describe, live: () async => 0),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'no recording')),
      );
    });

    test('the rejection error type is the adapter\'s choice', () async {
      final recorder = _ScriptedRecorder(RejectRequest('no recording'));

      await expectLater(
        recorder.run<int>(
          describe: _describe,
          live: () async => 0,
          reject: FormatException.new,
        ),
        throwsFormatException,
      );
    });
  });
}
