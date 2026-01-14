import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingEvent', () {
    test('creates event with all fields', () {
      final timestamp = DateTime.now();
      final event = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: timestamp,
        source: 'dio',
      );

      expect(event.fixtureKey, 'GET /users');
      expect(event.selectedIdentifier, 'success');
      expect(event.timestamp, timestamp);
      expect(event.source, 'dio');
    });

    test('creates event without source', () {
      final event = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: DateTime.now(),
      );

      expect(event.source, isNull);
    });

    test('toJson includes all fields', () {
      final timestamp = DateTime(2026, 1, 13, 10, 30, 15);
      final event = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: timestamp,
        source: 'dio',
      );

      final json = event.toJson();

      expect(json['fixtureKey'], 'GET /users');
      expect(json['selectedIdentifier'], 'success');
      expect(json['timestamp'], '2026-01-13T10:30:15.000');
      expect(json['source'], 'dio');
    });

    test('toJson excludes null source', () {
      final event = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: DateTime.now(),
      );

      final json = event.toJson();

      expect(json.containsKey('source'), isFalse);
    });

    test('fromJson creates event correctly', () {
      final json = {
        'fixtureKey': 'GET /users',
        'selectedIdentifier': 'success',
        'timestamp': '2026-01-13T10:30:15.000',
        'source': 'dio',
      };

      final event = RecordingEvent.fromJson(json);

      expect(event.fixtureKey, 'GET /users');
      expect(event.selectedIdentifier, 'success');
      expect(event.timestamp, DateTime(2026, 1, 13, 10, 30, 15));
      expect(event.source, 'dio');
    });

    test('fromJson handles missing source', () {
      final json = {
        'fixtureKey': 'GET /users',
        'selectedIdentifier': 'success',
        'timestamp': '2026-01-13T10:30:15.000',
      };

      final event = RecordingEvent.fromJson(json);

      expect(event.source, isNull);
    });

    test('equality works correctly', () {
      final timestamp = DateTime(2026, 1, 13, 10, 30, 15);
      final event1 = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: timestamp,
        source: 'dio',
      );
      final event2 = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: timestamp,
        source: 'dio',
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('toString includes all fields', () {
      final timestamp = DateTime(2026, 1, 13, 10, 30, 15);
      final event = RecordingEvent(
        fixtureKey: 'GET /users',
        selectedIdentifier: 'success',
        timestamp: timestamp,
        source: 'dio',
      );

      final string = event.toString();

      expect(string, contains('GET /users'));
      expect(string, contains('success'));
      expect(string, contains('dio'));
    });
  });
}
