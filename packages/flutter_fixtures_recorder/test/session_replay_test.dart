import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordedRequest request(
  String target, {
  String source = 'http',
  String operation = 'GET',
}) {
  return RecordedRequest(source: source, operation: operation, target: target);
}

RecordedInteraction interaction(
  String target, {
  String source = 'http',
  String operation = 'GET',
  Object? response,
}) {
  return RecordedInteraction(
    request: request(target, source: source, operation: operation),
    response: response,
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
  group('RecordedRequest.defaultKey', () {
    test('combines source, operation and target', () {
      expect(
        RecordedRequest.defaultKey(
            request('/users', source: 'http', operation: 'GET')),
        'http GET /users',
      );
    });

    test('distinguishes sources, operations and targets', () {
      String key(RecordedRequest r) => RecordedRequest.defaultKey(r);
      expect(
        key(request('/users', source: 'http')),
        isNot(key(request('/users', source: 'sqlite'))),
      );
      expect(
        key(request('/users', operation: 'GET')),
        isNot(key(request('/users', operation: 'POST'))),
      );
      expect(
        key(request('/users')),
        isNot(key(request('/orders'))),
      );
    });

    test('the payload does not participate in matching', () {
      final withPayload = RecordedRequest(
        source: 'http',
        operation: 'POST',
        target: '/login',
        payload: {'user': 'ada'},
      );
      expect(
        RecordedRequest.defaultKey(withPayload),
        RecordedRequest.defaultKey(request('/login', operation: 'POST')),
      );
    });
  });

  group('SessionReplay', () {
    test('serves repeated requests in recorded order', () {
      final replay = SessionReplay(session([
        interaction('/status', response: 'pending'),
        interaction('/status', response: 'pending'),
        interaction('/status', response: 'done'),
      ]));

      Object? next() => replay.next(request('/status'))?.response;
      expect(next(), 'pending');
      expect(next(), 'pending');
      expect(next(), 'done');
    });

    test('repeats the last recording once a key is exhausted', () {
      final replay = SessionReplay(session([
        interaction('/status', response: 'pending'),
        interaction('/status', response: 'done'),
      ]));

      replay.next(request('/status'));
      replay.next(request('/status'));
      expect(replay.next(request('/status'))?.response, 'done');
    });

    test('keeps an independent cursor per request key', () {
      final replay = SessionReplay(session([
        interaction('/a', response: 'a1'),
        interaction('/b', response: 'b1'),
        interaction('/a', response: 'a2'),
      ]));

      expect(replay.next(request('/a'))?.response, 'a1');
      expect(replay.next(request('/a'))?.response, 'a2');
      expect(replay.next(request('/b'))?.response, 'b1');
    });

    test('sources with the same target do not collide', () {
      final replay = SessionReplay(session([
        interaction('users', source: 'http', response: 'from http'),
        interaction('users', source: 'sqlite', response: 'from sqlite'),
      ]));

      expect(
        replay.next(request('users', source: 'sqlite'))?.response,
        'from sqlite',
      );
      expect(
        replay.next(request('users', source: 'http'))?.response,
        'from http',
      );
    });

    test('returns null for requests that were never recorded', () {
      final replay = SessionReplay(session([interaction('/a')]));
      expect(replay.next(request('/unknown')), isNull);
    });

    test('restart rewinds every cursor', () {
      final replay = SessionReplay(session([
        interaction('/status', response: 'first'),
        interaction('/status', response: 'second'),
      ]));

      replay.next(request('/status'));
      replay.restart();
      expect(replay.next(request('/status'))?.response, 'first');
    });

    test('honors a custom request key builder', () {
      final replay = SessionReplay(
        session([interaction('/users?ts=1', response: 'ok')]),
        keyOf: (request) =>
            '${request.source} ${request.operation} ${request.target.split('?').first}',
      );

      expect(replay.next(request('/users?ts=999'))?.response, 'ok');
    });
  });
}
