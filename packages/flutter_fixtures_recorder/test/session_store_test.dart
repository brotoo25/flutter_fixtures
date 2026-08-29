import 'dart:convert';
import 'dart:io';

import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

RecordingSession session(String id, {DateTime? recordedAt, Object? body}) {
  return RecordingSession(
    id: id,
    name: 'Session $id',
    recordedAt: recordedAt ?? DateTime(2026, 8, 28),
    interactions: [
      RecordedInteraction(
        request: RecordedRequest(
          source: 'http',
          operation: 'GET',
          target: '/users?page=1',
          payload: {'filter': 'active'},
        ),
        response: body ??
            {
              'statusCode': 200,
              'headers': {
                'content-type': ['application/json'],
              },
              'body': {'users': []},
            },
        recordedAt: DateTime(2026, 8, 28, 10, 30),
      ),
    ],
  );
}

void main() {
  group('RecordingSession JSON', () {
    test('round-trips through toJson/fromJson', () {
      final original = session('s1');
      final restored = RecordingSession.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.recordedAt, original.recordedAt);
      expect(restored.interactions, hasLength(1));

      final interaction = restored.interactions.single;
      final source = original.interactions.single;
      expect(interaction.request.source, source.request.source);
      expect(interaction.request.operation, source.request.operation);
      expect(interaction.request.target, source.request.target);
      expect(interaction.request.payload, source.request.payload);
      expect(interaction.response, source.response);
      expect(interaction.recordedAt, source.recordedAt);
    });

    test('the memory store accepts any response value', () async {
      // No encoding boundary is crossed, so the round-trip contract cannot
      // be violated here.
      final store = MemoryRecordingSessionStore();
      await store.save(session('s1', body: Object()));
      expect((await store.load('s1'))?.id, 's1');
    });
  });

  group('MemoryRecordingSessionStore', () {
    test('saves, loads, lists newest-first, and deletes', () async {
      final store = MemoryRecordingSessionStore();
      await store.save(session('old', recordedAt: DateTime(2026, 1, 1)));
      await store.save(session('new', recordedAt: DateTime(2026, 6, 1)));

      expect((await store.load('old'))?.id, 'old');
      expect((await store.list()).map((s) => s.id), ['new', 'old']);

      await store.delete('old');
      expect(await store.load('old'), isNull);
      await store.delete('missing'); // no-op
    });
  });

  group('FileRecordingSessionStore', () {
    late Directory dir;
    late FileRecordingSessionStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('recorder_store_test');
      store = FileRecordingSessionStore(dir.path);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('saves, loads, lists newest-first, and deletes', () async {
      await store.save(session('old', recordedAt: DateTime(2026, 1, 1)));
      await store.save(session('new', recordedAt: DateTime(2026, 6, 1)));

      final loaded = await store.load('old');
      final response = loaded?.interactions.single.response as Map?;
      expect(response?['body'], {'users': []});
      expect((await store.list()).map((s) => s.id), ['new', 'old']);

      await store.delete('old');
      expect(await store.load('old'), isNull);
      await store.delete('missing'); // no-op
    });

    test('listing an unused directory returns empty', () async {
      expect(await store.list(), isEmpty);
    });

    test('creates its directory on first save', () async {
      final nested = FileRecordingSessionStore('${dir.path}/nested/deep');
      await nested.save(session('s1'));
      expect((await nested.load('s1'))?.id, 's1');
    });

    test('resolves a deferred directory lazily on first use', () async {
      var resolved = false;
      final deferred = FileRecordingSessionStore.deferred(() async {
        resolved = true;
        return '${dir.path}/deferred';
      });
      expect(resolved, isFalse);

      await deferred.save(session('s1'));
      expect(resolved, isTrue);
      expect((await deferred.load('s1'))?.id, 's1');
    });

    test('saving the same id overwrites', () async {
      await store.save(session('s1'));
      await store.save(RecordingSession(
        id: 's1',
        name: 'Renamed',
        recordedAt: DateTime(2026, 8, 29),
        interactions: const [],
      ));

      expect((await store.load('s1'))?.name, 'Renamed');
      expect(await store.list(), hasLength(1));
    });

    test('a response that cannot be JSON-encoded fails loudly at save',
        () async {
      expect(
        () => store.save(session('bad', body: Object())),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Session bad'),
        )),
      );
      expect(await store.list(), isEmpty);
    });

    test('a malformed session file fails loudly on list and load', () async {
      File('${dir.path}/bad.json').writeAsStringSync('not json');
      expect(store.list(), throwsFormatException);
      expect(store.load('bad'), throwsFormatException);
    });

    test('sessionStoreForDirectory returns a working file store', () async {
      final store = sessionStoreForDirectory(() async => '${dir.path}/factory');
      expect(store, isA<FileRecordingSessionStore>());
      await store.save(session('s1'));
      expect((await store.list()).single.id, 's1');
    });
  });
}
