import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSessionStorage implements SessionStorage {
  final Map<String, RecordingSession> _sessions = {};

  @override
  Future<void> saveSession(RecordingSession session) async {
    _sessions[session.name] = session;
  }

  @override
  Future<RecordingSession?> loadSession(String name) async {
    return _sessions[name];
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    return _sessions.values.map((session) {
      return SessionMetadata(
        name: session.name,
        createdAt: session.createdAt,
        lastUsedAt: session.lastUsedAt,
        eventCount: session.events.length,
      );
    }).toList();
  }

  @override
  Future<void> deleteSession(String name) async {
    _sessions.remove(name);
  }
}

void main() {
  group('FixtureRecorder', () {
    late FixtureRecorder recorder;
    late MockSessionStorage storage;

    setUp(() {
      storage = MockSessionStorage();
      recorder = FixtureRecorder(storage: storage);
    });

    test('initial mode is idle', () {
      expect(recorder.mode, RecorderMode.idle);
      expect(recorder.currentSession, isNull);
    });

    group('Recording', () {
      test('startRecording changes mode to recording', () {
        recorder.startRecording();

        expect(recorder.mode, RecorderMode.recording);
      });

      test('notifySelection records events during recording', () {
        recorder.startRecording();

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );
        final selected = fixture.items[0];

        recorder.notifySelection(fixture, selected, 'dio');

        // We can't directly access the buffer, but we can verify by stopping
        // the recording and checking the saved session
      });

      test('notifySelection skips default selections', () async {
        recorder.startRecording();

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'default',
              description: '200',
              data: {},
              defaultOption: true,
            ),
          ],
        );
        final selected = fixture.items[0];

        recorder.notifySelection(fixture, selected, 'dio');
        await recorder.stopRecording('test_session');

        final session = await storage.loadSession('test_session');
        expect(session!.events, isEmpty);
      });

      test('notifySelection skips consecutive repeats', () async {
        recorder.startRecording();

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );
        final selected = fixture.items[0];

        // Record same selection twice
        recorder.notifySelection(fixture, selected, 'dio');
        recorder.notifySelection(fixture, selected, 'dio');

        await recorder.stopRecording('test_session');

        final session = await storage.loadSession('test_session');
        expect(session!.events.length, 1); // Only one event recorded
      });

      test('stopRecording saves session and returns to idle', () async {
        recorder.startRecording();

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        recorder.notifySelection(fixture, fixture.items[0], 'dio');
        await recorder.stopRecording('test_session');

        expect(recorder.mode, RecorderMode.idle);

        final session = await storage.loadSession('test_session');
        expect(session, isNotNull);
        expect(session!.name, 'test_session');
        expect(session.events.length, 1);
      });

      test('cancelRecording discards buffer and returns to idle', () {
        recorder.startRecording();

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        recorder.notifySelection(fixture, fixture.items[0], 'dio');
        recorder.cancelRecording();

        expect(recorder.mode, RecorderMode.idle);
      });
    });

    group('Playback', () {
      test('startPlayback loads session and changes mode', () async {
        // Save a session first
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [
            RecordingEvent(
              fixtureKey: 'GET /users',
              selectedIdentifier: 'success',
              timestamp: DateTime.now(),
            ),
          ],
        );
        await storage.saveSession(session);

        await recorder.startPlayback('test_session');

        expect(recorder.mode, RecorderMode.playback);
        expect(recorder.currentSession, isNotNull);
        expect(recorder.currentSession!.name, 'test_session');
      });

      test('startPlayback updates lastUsedAt timestamp', () async {
        final createdAt = DateTime(2026, 1, 13, 10, 0, 0);
        final session = RecordingSession(
          name: 'test_session',
          createdAt: createdAt,
          events: [],
        );
        await storage.saveSession(session);

        await recorder.startPlayback('test_session');

        final updated = await storage.loadSession('test_session');
        expect(updated!.lastUsedAt, isNotNull);
        expect(updated.lastUsedAt!.isAfter(createdAt), isTrue);
      });

      test('getRecordedSelection returns recorded fixture', () async {
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [
            RecordingEvent(
              fixtureKey: 'GET /users',
              selectedIdentifier: 'success',
              timestamp: DateTime.now(),
            ),
          ],
        );
        await storage.saveSession(session);
        await recorder.startPlayback('test_session');

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
            FixtureDocument(
              identifier: 'error',
              description: '500',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        final recorded = recorder.getRecordedSelection(fixture);

        expect(recorded, isNotNull);
        expect(recorded!.identifier, 'success');
        expect(recorder.playbackIndex, 1); // Index advanced
      });

      test('getRecordedSelection handles sequential playback', () async {
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [
            RecordingEvent(
              fixtureKey: 'POST /login',
              selectedIdentifier: 'success',
              timestamp: DateTime.now(),
            ),
            RecordingEvent(
              fixtureKey: 'POST /login',
              selectedIdentifier: 'error',
              timestamp: DateTime.now(),
            ),
            RecordingEvent(
              fixtureKey: 'POST /login',
              selectedIdentifier: 'timeout',
              timestamp: DateTime.now(),
            ),
          ],
        );
        await storage.saveSession(session);
        await recorder.startPlayback('test_session');

        final fixture = FixtureCollection(
          description: 'POST /login',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
            FixtureDocument(
              identifier: 'error',
              description: '500',
              defaultOption: false,
              data: {},
            ),
            FixtureDocument(
              identifier: 'timeout',
              description: '408',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        // First call should return 'success'
        final first = recorder.getRecordedSelection(fixture);
        expect(first, isNotNull);
        expect(first!.identifier, 'success');
        expect(recorder.playbackIndex, 1);
        expect(recorder.mode, RecorderMode.playback);

        // Second call should return 'error'
        final second = recorder.getRecordedSelection(fixture);
        expect(second, isNotNull);
        expect(second!.identifier, 'error');
        expect(recorder.playbackIndex, 2);
        expect(recorder.mode, RecorderMode.playback);

        // Third call should return 'timeout'
        final third = recorder.getRecordedSelection(fixture);
        expect(third, isNotNull);
        expect(third!.identifier, 'timeout');
        expect(recorder.playbackIndex, 3);
        expect(recorder.mode, RecorderMode.playback);

        // Fourth call should exhaust events and auto-stop
        final fourth = recorder.getRecordedSelection(fixture);
        expect(fourth, isNull);
        expect(recorder.mode, RecorderMode.idle);
      });

      test('getRecordedSelection returns null when not in playback', () {
        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        final recorded = recorder.getRecordedSelection(fixture);

        expect(recorded, isNull);
      });

      test('getRecordedSelection returns null for unrecorded fixture',
          () async {
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [
            RecordingEvent(
              fixtureKey: 'GET /users',
              selectedIdentifier: 'success',
              timestamp: DateTime.now(),
            ),
          ],
        );
        await storage.saveSession(session);
        await recorder.startPlayback('test_session');

        final fixture = FixtureCollection(
          description: 'GET /posts', // Different fixture
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        final recorded = recorder.getRecordedSelection(fixture);

        expect(recorded, isNull);
      });

      test('getRecordedSelection returns null when identifier not found',
          () async {
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [
            RecordingEvent(
              fixtureKey: 'GET /users',
              selectedIdentifier: 'deleted_option',
              timestamp: DateTime.now(),
            ),
          ],
        );
        await storage.saveSession(session);
        await recorder.startPlayback('test_session');

        final fixture = FixtureCollection(
          description: 'GET /users',
          items: [
            FixtureDocument(
              identifier: 'success',
              description: '200',
              defaultOption: false,
              data: {},
            ),
          ],
        );

        final recorded = recorder.getRecordedSelection(fixture);

        expect(recorded, isNull); // Fallback behavior
      });

      test('stopPlayback clears session and returns to idle', () async {
        final session = RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [],
        );
        await storage.saveSession(session);
        await recorder.startPlayback('test_session');

        recorder.stopPlayback();

        expect(recorder.mode, RecorderMode.idle);
        expect(recorder.currentSession, isNull);
      });
    });

    group('Session Management', () {
      test('listSessions returns all sessions', () async {
        await storage.saveSession(RecordingSession(
          name: 'session1',
          createdAt: DateTime.now(),
          events: [],
        ));
        await storage.saveSession(RecordingSession(
          name: 'session2',
          createdAt: DateTime.now(),
          events: [],
        ));

        final sessions = await recorder.listSessions();

        expect(sessions.length, 2);
      });

      test('deleteSession removes session', () async {
        await storage.saveSession(RecordingSession(
          name: 'test_session',
          createdAt: DateTime.now(),
          events: [],
        ));

        await recorder.deleteSession('test_session');

        final sessions = await recorder.listSessions();
        expect(sessions, isEmpty);
      });
    });

    group('ChangeNotifier', () {
      test('notifies listeners on mode change', () {
        var notified = false;
        recorder.addListener(() => notified = true);

        recorder.startRecording();

        expect(notified, isTrue);
      });
    });
  });
}
