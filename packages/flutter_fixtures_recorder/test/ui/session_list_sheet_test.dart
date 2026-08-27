import 'package:flutter/material.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordingSession session(String id, String name) {
  return RecordingSession(
    id: id,
    name: name,
    recordedAt: DateTime(2026, 8, 28),
    interactions: [
      RecordedInteraction(
        request: RecordedRequest(
          source: 'http',
          operation: 'GET',
          target: '/users',
        ),
        recordedAt: DateTime(2026, 8, 28),
      ),
    ],
  );
}

Widget app(FixtureRecorder recorder) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRecordingSessionsSheet(context, recorder),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  late MemoryRecordingSessionStore store;
  late FixtureRecorder recorder;

  setUp(() {
    store = MemoryRecordingSessionStore();
    recorder = FixtureRecorder(store: store);
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(app(recorder));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when nothing was recorded', (tester) async {
    await openSheet(tester);
    expect(find.textContaining('No recorded sessions yet'), findsOneWidget);
  });

  testWidgets('lists sessions and starts replay on tap', (tester) async {
    await store.save(session('s1', 'Checkout demo'));
    await openSheet(tester);

    expect(find.text('Checkout demo'), findsOneWidget);
    expect(find.text('1 interactions'), findsOneWidget);

    await tester.tap(find.text('Checkout demo'));
    await tester.pumpAndSettle();

    expect(recorder.isReplaying, isTrue);
    expect(recorder.replaySession?.id, 's1');
  });

  testWidgets('delete removes the session from the store', (tester) async {
    await store.save(session('s1', 'Checkout demo'));
    await openSheet(tester);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout demo'), findsNothing);
    expect(await store.list(), isEmpty);
  });

  testWidgets('tapping a session while replaying switches sessions',
      (tester) async {
    await store.save(session('s1', 'First'));
    recorder.startReplayOf(session('s2', 'Second'));
    await openSheet(tester);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(recorder.replaySession?.id, 's1');
  });

  testWidgets('stop replay button appears while replaying', (tester) async {
    await store.save(session('s1', 'First'));
    recorder.startReplayOf(session('s1', 'First'));
    await openSheet(tester);

    await tester.tap(find.text('Stop replay'));
    await tester.pumpAndSettle();

    expect(recorder.mode, RecorderMode.idle);
  });
}
