import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingSession', () {
    test('creates session with all fields', () {
      final createdAt = DateTime.now();
      final lastUsedAt = DateTime.now().add(const Duration(hours: 1));
      final events = [
        RecordingEvent(
          fixtureKey: 'GET /users',
          selectedIdentifier: 'success',
          timestamp: DateTime.now(),
        ),
      ];

      final session = RecordingSession(
        name: 'test_session',
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
        events: events,
      );

      expect(session.name, 'test_session');
      expect(session.createdAt, createdAt);
      expect(session.lastUsedAt, lastUsedAt);
      expect(session.events, events);
    });

    test('creates session without lastUsedAt', () {
      final session = RecordingSession(
        name: 'test_session',
        createdAt: DateTime.now(),
        events: [],
      );

      expect(session.lastUsedAt, isNull);
    });

    test('toJson includes all fields', () {
      final createdAt = DateTime(2026, 1, 13, 10, 0, 0);
      final lastUsedAt = DateTime(2026, 1, 13, 15, 0, 0);
      final events = [
        RecordingEvent(
          fixtureKey: 'GET /users',
          selectedIdentifier: 'success',
          timestamp: DateTime(2026, 1, 13, 10, 30, 0),
        ),
      ];

      final session = RecordingSession(
        name: 'test_session',
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
        events: events,
      );

      final json = session.toJson();

      expect(json['name'], 'test_session');
      expect(json['createdAt'], '2026-01-13T10:00:00.000');
      expect(json['lastUsedAt'], '2026-01-13T15:00:00.000');
      expect(json['events'], isA<List>());
      expect((json['events'] as List).length, 1);
    });

    test('toJson excludes null lastUsedAt', () {
      final session = RecordingSession(
        name: 'test_session',
        createdAt: DateTime.now(),
        events: [],
      );

      final json = session.toJson();

      expect(json.containsKey('lastUsedAt'), isFalse);
    });

    test('fromJson creates session correctly', () {
      final json = {
        'name': 'test_session',
        'createdAt': '2026-01-13T10:00:00.000',
        'lastUsedAt': '2026-01-13T15:00:00.000',
        'events': [
          {
            'fixtureKey': 'GET /users',
            'selectedIdentifier': 'success',
            'timestamp': '2026-01-13T10:30:00.000',
          },
        ],
      };

      final session = RecordingSession.fromJson(json);

      expect(session.name, 'test_session');
      expect(session.createdAt, DateTime(2026, 1, 13, 10, 0, 0));
      expect(session.lastUsedAt, DateTime(2026, 1, 13, 15, 0, 0));
      expect(session.events.length, 1);
      expect(session.events[0].fixtureKey, 'GET /users');
    });

    test('fromJson handles missing lastUsedAt', () {
      final json = {
        'name': 'test_session',
        'createdAt': '2026-01-13T10:00:00.000',
        'events': [],
      };

      final session = RecordingSession.fromJson(json);

      expect(session.lastUsedAt, isNull);
    });

    test('copyWith creates new instance with updated fields', () {
      final session = RecordingSession(
        name: 'test_session',
        createdAt: DateTime(2026, 1, 13),
        events: [],
      );

      final updated = session.copyWith(
        name: 'updated_session',
        lastUsedAt: DateTime(2026, 1, 14),
      );

      expect(updated.name, 'updated_session');
      expect(updated.createdAt, session.createdAt);
      expect(updated.lastUsedAt, DateTime(2026, 1, 14));
      expect(updated.events, session.events);
    });

    test('copyWith with no changes returns equivalent session', () {
      final session = RecordingSession(
        name: 'test_session',
        createdAt: DateTime(2026, 1, 13),
        events: [],
      );

      final copy = session.copyWith();

      expect(copy.name, session.name);
      expect(copy.createdAt, session.createdAt);
      expect(copy.lastUsedAt, session.lastUsedAt);
      expect(copy.events, session.events);
    });

    test('toString includes session details', () {
      final session = RecordingSession(
        name: 'test_session',
        createdAt: DateTime(2026, 1, 13),
        events: [
          RecordingEvent(
            fixtureKey: 'GET /users',
            selectedIdentifier: 'success',
            timestamp: DateTime.now(),
          ),
        ],
      );

      final string = session.toString();

      expect(string, contains('test_session'));
      expect(string, contains('1 events'));
    });
  });
}
