import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordedInteraction interaction(
  String method,
  String url, {
  int statusCode = 200,
  Object? body,
}) {
  return RecordedInteraction(
    method: method,
    uri: Uri.parse(url),
    statusCode: statusCode,
    responseBody: body,
    recordedAt: DateTime(2026, 8, 28),
  );
}

RecordingSession session(List<RecordedInteraction> interactions) {
  return RecordingSession(
    id: 's1',
    name: 'Test session',
    recordedAt: DateTime(2026, 8, 28),
    interactions: interactions,
  );
}

void main() {
  group('RecordedInteraction.defaultKey', () {
    test('combines method, path and sorted query', () {
      expect(
        RecordedInteraction.defaultKey(
            'get', Uri.parse('https://api.test/users?b=2&a=1')),
        'GET /users?a=1&b=2',
      );
    });

    test('ignores the host so environments can differ', () {
      final recorded = RecordedInteraction.defaultKey(
          'GET', Uri.parse('https://staging.test/users'));
      final live = RecordedInteraction.defaultKey(
          'GET', Uri.parse('https://prod.test/users'));
      expect(recorded, live);
    });

    test('distinguishes methods and query values', () {
      expect(
        RecordedInteraction.defaultKey('GET', Uri.parse('/users?page=1')),
        isNot(
            RecordedInteraction.defaultKey('GET', Uri.parse('/users?page=2'))),
      );
      expect(
        RecordedInteraction.defaultKey('GET', Uri.parse('/users')),
        isNot(RecordedInteraction.defaultKey('POST', Uri.parse('/users'))),
      );
    });
  });

  group('SessionReplay', () {
    test('serves repeated requests in recorded order', () {
      final replay = SessionReplay(session([
        interaction('GET', '/status', body: 'pending'),
        interaction('GET', '/status', body: 'pending'),
        interaction('GET', '/status', body: 'done'),
      ]));

      Object? next() => replay.next('GET', Uri.parse('/status'))?.responseBody;
      expect(next(), 'pending');
      expect(next(), 'pending');
      expect(next(), 'done');
    });

    test('repeats the last recording once a key is exhausted', () {
      final replay = SessionReplay(session([
        interaction('GET', '/status', body: 'pending'),
        interaction('GET', '/status', body: 'done'),
      ]));

      replay.next('GET', Uri.parse('/status'));
      replay.next('GET', Uri.parse('/status'));
      expect(
        replay.next('GET', Uri.parse('/status'))?.responseBody,
        'done',
      );
    });

    test('keeps an independent cursor per request key', () {
      final replay = SessionReplay(session([
        interaction('GET', '/a', body: 'a1'),
        interaction('GET', '/b', body: 'b1'),
        interaction('GET', '/a', body: 'a2'),
      ]));

      expect(replay.next('GET', Uri.parse('/a'))?.responseBody, 'a1');
      expect(replay.next('GET', Uri.parse('/a'))?.responseBody, 'a2');
      expect(replay.next('GET', Uri.parse('/b'))?.responseBody, 'b1');
    });

    test('returns null for requests that were never recorded', () {
      final replay = SessionReplay(session([interaction('GET', '/a')]));
      expect(replay.next('GET', Uri.parse('/unknown')), isNull);
    });

    test('restart rewinds every cursor', () {
      final replay = SessionReplay(session([
        interaction('GET', '/status', body: 'first'),
        interaction('GET', '/status', body: 'second'),
      ]));

      replay.next('GET', Uri.parse('/status'));
      replay.restart();
      expect(replay.next('GET', Uri.parse('/status'))?.responseBody, 'first');
    });

    test('honors a custom request key builder', () {
      final replay = SessionReplay(
        session([interaction('GET', '/users?ts=1', body: 'ok')]),
        keyOf: (method, uri) => '$method ${uri.path}',
      );

      expect(
        replay.next('GET', Uri.parse('/users?ts=999'))?.responseBody,
        'ok',
      );
    });
  });
}
