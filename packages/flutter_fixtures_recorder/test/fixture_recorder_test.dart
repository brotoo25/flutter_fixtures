import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordedInteraction interaction(String method, String url, {Object? body}) {
  return RecordedInteraction(
    method: method,
    uri: Uri.parse(url),
    statusCode: 200,
    responseBody: body,
    recordedAt: DateTime(2026, 8, 28),
  );
}

void main() {
  late MemoryRecordingSessionStore store;
  late FixtureRecorder recorder;

  setUp(() {
    store = MemoryRecordingSessionStore();
    recorder = FixtureRecorder(store: store);
  });

  group('recording', () {
    test('captures interactions and saves a session on stop', () async {
      recorder.startRecording(name: 'Demo');
      recorder.record(interaction('GET', '/users'));
      recorder.record(interaction('POST', '/login'));

      final session = await recorder.stopRecording();

      expect(session, isNotNull);
      expect(session!.name, 'Demo');
      expect(session.interactions, hasLength(2));
      expect(recorder.mode, RecorderMode.idle);
      expect(await store.load(session.id), isNotNull);
    });

    test('a name given at stop time wins', () async {
      recorder.startRecording(name: 'Draft');
      recorder.record(interaction('GET', '/users'));
      final session = await recorder.stopRecording(name: 'Final');
      expect(session!.name, 'Final');
    });

    test('an unnamed session gets a timestamped default name', () async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users'));
      final session = await recorder.stopRecording();
      expect(session!.name, startsWith('Session '));
    });

    test('discard saves nothing', () async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users'));
      final session = await recorder.stopRecording(discard: true);
      expect(session, isNull);
      expect(await store.list(), isEmpty);
    });

    test('an empty recording is not saved', () async {
      recorder.startRecording();
      final session = await recorder.stopRecording();
      expect(session, isNull);
      expect(await store.list(), isEmpty);
    });

    test('record is a no-op while idle', () {
      recorder.record(interaction('GET', '/users'));
      expect(recorder.recordedCount, 0);
    });

    test('stopRecording while idle returns null', () async {
      expect(await recorder.stopRecording(), isNull);
    });

    test('notifies listeners on mode changes and captures', () {
      var notifications = 0;
      recorder.addListener(() => notifications++);

      recorder.startRecording();
      recorder.record(interaction('GET', '/users'));
      expect(notifications, 2);
    });
  });

  group('replay', () {
    late RecordingSession saved;

    setUp(() async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users', body: 'recorded'));
      saved = (await recorder.stopRecording())!;
    });

    test('startReplay loads the session and serves responses', () async {
      await recorder.startReplay(saved.id);

      expect(recorder.isReplaying, isTrue);
      expect(recorder.replaySession?.id, saved.id);
      expect(
        recorder.replayResponseFor('GET', Uri.parse('/users'))?.responseBody,
        'recorded',
      );
    });

    test('startReplay with an unknown id throws', () {
      expect(() => recorder.startReplay('nope'), throwsStateError);
    });

    test('replayResponseFor returns null while idle', () {
      expect(recorder.replayResponseFor('GET', Uri.parse('/users')), isNull);
    });

    test('stopReplay returns to idle and is idempotent', () async {
      await recorder.startReplay(saved.id);
      recorder.stopReplay();
      recorder.stopReplay();
      expect(recorder.mode, RecorderMode.idle);
      expect(recorder.replaySession, isNull);
    });
  });

  group('mode guards', () {
    test('cannot start recording while recording', () {
      recorder.startRecording();
      expect(() => recorder.startRecording(), throwsStateError);
    });

    test('cannot start replay while recording', () {
      recorder.startRecording();
      expect(
        () => recorder.startReplayOf(RecordingSession(
          id: 'x',
          name: 'x',
          recordedAt: DateTime.now(),
          interactions: const [],
        )),
        throwsStateError,
      );
    });
  });

  group('session management', () {
    test('sessions() lists what the store holds', () async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users'));
      final saved = (await recorder.stopRecording())!;

      final listed = await recorder.sessions();
      expect(listed.map((s) => s.id), [saved.id]);
    });

    test('deleteSession removes from the store', () async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users'));
      final saved = (await recorder.stopRecording())!;

      await recorder.deleteSession(saved.id);
      expect(await recorder.sessions(), isEmpty);
    });
  });
}
