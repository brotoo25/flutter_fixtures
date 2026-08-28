import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordedRequest request(String operation, String target) {
  return RecordedRequest(source: 'http', operation: operation, target: target);
}

RecordedInteraction interaction(String operation, String target,
    {Object? body}) {
  return RecordedInteraction(
    request: request(operation, target),
    response: body,
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

    test('a blank name counts as absent', () async {
      recorder.startRecording(name: '  ');
      recorder.record(interaction('GET', '/users'));
      final session = await recorder.stopRecording(name: '');
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
      final decision = recorder.decide(request('GET', '/users'));
      expect(decision, isA<Replayed>());
      expect((decision as Replayed).interaction.response, 'recorded');
    });

    test('startReplay with an unknown id throws', () {
      expect(() => recorder.startReplay('nope'), throwsStateError);
    });

    test('starting a replay while replaying switches sessions', () async {
      await recorder.startReplay(saved.id);
      final other = RecordingSession(
        id: 'other',
        name: 'Other',
        recordedAt: DateTime(2026, 8, 28),
        interactions: [interaction('GET', '/users', body: 'other')],
      );

      recorder.startReplayOf(other);

      expect(recorder.replaySession?.id, 'other');
      final decision = recorder.decide(request('GET', '/users'));
      expect((decision as Replayed).interaction.response, 'other');
    });

    test('stopReplay returns to idle and is idempotent', () async {
      await recorder.startReplay(saved.id);
      recorder.stopReplay();
      recorder.stopReplay();
      expect(recorder.mode, RecorderMode.idle);
      expect(recorder.replaySession, isNull);
    });

    test('restartReplay rewinds the session to the beginning', () async {
      recorder.startReplayOf(RecordingSession(
        id: 'seq',
        name: 'Sequence',
        recordedAt: DateTime(2026, 8, 28),
        interactions: [
          interaction('GET', '/status', body: 'first'),
          interaction('GET', '/status', body: 'second'),
        ],
      ));

      recorder.decide(request('GET', '/status'));
      recorder.restartReplay();
      final decision = recorder.decide(request('GET', '/status'));
      expect((decision as Replayed).interaction.response, 'first');
    });

    test('a custom key builder threads through to replay matching', () {
      recorder = FixtureRecorder(
        store: store,
        keyOf: (request) =>
            '${request.source} ${request.operation} ${request.target.split('?').first}',
      );
      recorder.startReplayOf(RecordingSession(
        id: 'k',
        name: 'Keyed',
        recordedAt: DateTime(2026, 8, 28),
        interactions: [interaction('GET', '/users?ts=1', body: 'ok')],
      ));

      final decision = recorder.decide(request('GET', '/users?ts=999'));
      expect((decision as Replayed).interaction.response, 'ok');
    });
  });

  group('decide', () {
    late RecordingSession saved;

    setUp(() async {
      recorder.startRecording();
      recorder.record(interaction('GET', '/users', body: 'recorded'));
      saved = (await recorder.stopRecording())!;
    });

    test('forwards while idle, whatever the miss policy says', () {
      expect(recorder.decide(request('GET', '/users')), isA<ForwardToSource>());
      expect(
        recorder.decide(request('GET', '/users'),
            onMiss: ReplayMissBehavior.reject),
        isA<ForwardToSource>(),
      );
    });

    test('replays a recorded request', () async {
      await recorder.startReplay(saved.id);
      expect(recorder.decide(request('GET', '/users')), isA<Replayed>());
    });

    test('forwards a miss by default', () async {
      await recorder.startReplay(saved.id);
      expect(
          recorder.decide(request('GET', '/unknown')), isA<ForwardToSource>());
    });

    test('rejects a miss with the session named in the message', () async {
      await recorder.startReplay(saved.id);
      final decision = recorder.decide(
        request('GET', '/unknown'),
        onMiss: ReplayMissBehavior.reject,
      );
      expect(decision, isA<RejectRequest>());
      final message = (decision as RejectRequest).message;
      expect(message, contains('GET /unknown'));
      expect(message, contains(saved.name));
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
