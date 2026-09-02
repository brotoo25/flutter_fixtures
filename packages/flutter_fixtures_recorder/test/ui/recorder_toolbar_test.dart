import 'package:flutter/material.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordedInteraction interaction() {
  return RecordedInteraction(
    request: RecordedRequest(
      source: 'http',
      operation: 'GET',
      target: '/users',
    ),
    recordedAt: DateTime(2026, 8, 28),
  );
}

Widget app(FixtureRecorder recorder) {
  return MaterialApp(
    home: Scaffold(body: RecorderToolbar(recorder: recorder)),
  );
}

void main() {
  late FixtureRecorder recorder;

  setUp(() {
    recorder = FixtureRecorder(store: MemoryRecordingSessionStore());
  });

  testWidgets('idle: shows start-recording and sessions actions',
      (tester) async {
    await tester.pumpWidget(app(recorder));

    expect(find.text('Recorder idle'), findsOneWidget);
    await tester.tap(find.byTooltip('Start recording'));
    await tester.pump();

    expect(recorder.isRecording, isTrue);
    expect(find.text('Recording · 0'), findsOneWidget);
  });

  testWidgets('recording: count updates as traffic is captured',
      (tester) async {
    recorder.startRecording();
    await tester.pumpWidget(app(recorder));

    recorder.record(() => interaction());
    await tester.pump();

    expect(find.text('Recording · 1'), findsOneWidget);
  });

  testWidgets('stopping with traffic prompts for a name and saves',
      (tester) async {
    recorder.startRecording();
    recorder.record(() => interaction());
    await tester.pumpWidget(app(recorder));

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('Save recording'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My demo');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(recorder.mode, RecorderMode.idle);
    final sessions = await recorder.sessions();
    expect(sessions.single.name, 'My demo');
  });

  testWidgets('discarding from the stop dialog saves nothing', (tester) async {
    recorder.startRecording();
    recorder.record(() => interaction());
    await tester.pumpWidget(app(recorder));

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(recorder.mode, RecorderMode.idle);
    expect(await recorder.sessions(), isEmpty);
  });

  testWidgets('replaying: shows the session name and stop action',
      (tester) async {
    recorder.startReplayOf(RecordingSession(
      id: 's1',
      name: 'Checkout demo',
      recordedAt: DateTime(2026, 8, 28),
      interactions: [interaction()],
    ));
    await tester.pumpWidget(app(recorder));

    expect(find.text('Replaying "Checkout demo"'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop replay'));
    await tester.pump();
    expect(recorder.mode, RecorderMode.idle);
  });

  testWidgets('stopping an empty recording skips the prompt and saves nothing',
      (tester) async {
    recorder.startRecording();
    await tester.pumpWidget(app(recorder));

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('Save recording'), findsNothing);
    expect(find.text('Nothing recorded.'), findsOneWidget);
    expect(recorder.mode, RecorderMode.idle);
    expect(await recorder.sessions(), isEmpty);
  });

  testWidgets('a save the store rejects is reported and keeps recording',
      (tester) async {
    recorder = FixtureRecorder(store: _FailingStore());
    recorder.startRecording();
    recorder.record(() => interaction());
    await tester.pumpWidget(app(recorder));

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save the recording'), findsOneWidget);
    expect(recorder.isRecording, isTrue);
    expect(recorder.recordedCount, 1);
  });

  testWidgets('saving with a blank name falls back to the default',
      (tester) async {
    recorder.startRecording();
    recorder.record(() => interaction());
    await tester.pumpWidget(app(recorder));

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save')); // name field left empty
    await tester.pumpAndSettle();

    final sessions = await recorder.sessions();
    expect(sessions.single.name, startsWith('Session '));
  });

  testWidgets('restart replay rewinds the session', (tester) async {
    RecordedInteraction step(String body) => RecordedInteraction(
          request: RecordedRequest(
            source: 'http',
            operation: 'GET',
            target: '/status',
          ),
          response: body,
          recordedAt: DateTime(2026, 8, 28),
        );
    recorder.startReplayOf(RecordingSession(
      id: 'seq',
      name: 'Sequence',
      recordedAt: DateTime(2026, 8, 28),
      interactions: [step('first'), step('second')],
    ));
    await tester.pumpWidget(app(recorder));

    RecordedRequest request() =>
        RecordedRequest(source: 'http', operation: 'GET', target: '/status');
    recorder.decide(request);

    await tester.tap(find.byTooltip('Restart replay'));
    await tester.pump();

    final decision = recorder.decide(request);
    expect((decision as Replayed).interaction.response, 'first');
  });
}

class _FailingStore extends MemoryRecordingSessionStore {
  @override
  Future<void> save(RecordingSession session) async {
    throw StateError('disk full');
  }
}
