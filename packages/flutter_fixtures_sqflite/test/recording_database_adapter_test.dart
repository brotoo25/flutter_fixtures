import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:flutter_fixtures_sqflite/flutter_fixtures_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory stand-in for the real database: canned rows for reads,
/// counted calls so tests can assert whether the inner adapter was touched.
class FakeDatabaseAdapter implements DatabaseAdapter {
  List<Map<String, dynamic>> rows;
  int nextId;
  int calls = 0;

  FakeDatabaseAdapter({this.rows = const [], this.nextId = 1});

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    calls++;
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    calls++;
    return rows;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    conflictAlgorithm,
  }) async {
    calls++;
    return nextId++;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    conflictAlgorithm,
  }) async {
    calls++;
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    calls++;
    return 1;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    calls++;
    return nextId++;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    calls++;
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    calls++;
    return 1;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    calls++;
  }

  @override
  Future<void> close() async {}

  @override
  bool get isOpen => true;
}

void main() {
  late FixtureRecorder recorder;
  late FakeDatabaseAdapter inner;
  late RecordingDatabaseAdapter db;

  setUp(() {
    recorder = FixtureRecorder(store: MemoryRecordingSessionStore());
    inner = FakeDatabaseAdapter(rows: [
      {'id': 1, 'name': 'Ada'},
    ]);
    db = RecordingDatabaseAdapter(inner: inner, recorder: recorder);
  });

  group('while idle', () {
    test('delegates without capturing', () async {
      final rows = await db.query('users');
      expect(rows, [
        {'id': 1, 'name': 'Ada'}
      ]);
      expect(inner.calls, 1);
      expect(recorder.recordedCount, 0);
    });
  });

  group('recording', () {
    test('captures queries with their request description', () async {
      recorder.startRecording();
      await db.query('users', where: 'id = ?', whereArgs: [1]);

      final session = (await recorder.stopRecording())!;
      final interaction = session.interactions.single;
      expect(interaction.request.source, 'sqlite');
      expect(interaction.request.operation, 'query');
      expect(interaction.request.target, contains('"table":"users"'));
      expect(interaction.request.target, contains('"where":"id = ?"'));
      expect(interaction.response, [
        {'id': 1, 'name': 'Ada'}
      ]);
    });

    test('captures mutations and their results', () async {
      recorder.startRecording();
      final id = await db.insert('users', {'name': 'Grace'});
      expect(id, 1);

      final session = (await recorder.stopRecording())!;
      final interaction = session.interactions.single;
      expect(interaction.request.operation, 'insert');
      expect(interaction.response, 1);
    });
  });

  group('replaying', () {
    Future<RecordingSession> recordSession() async {
      recorder.startRecording();
      await db.query('users');
      await db.insert('users', {'name': 'Grace'});
      return (await recorder.stopRecording())!;
    }

    test('answers recorded operations without touching the inner adapter',
        () async {
      final session = await recordSession();
      final baseline = inner.calls;
      await recorder.startReplay(session.id);

      final rows = await db.query('users');
      final id = await db.insert('users', {'name': 'Grace'});

      expect(rows, [
        {'id': 1, 'name': 'Ada'}
      ]);
      expect(id, 1);
      expect(inner.calls, baseline);
    });

    test('replays a session that went through JSON persistence', () async {
      final session = await recordSession();
      final restored = RecordingSession.fromJson(session.toJson());
      recorder.startReplayOf(restored);

      final rows = await db.query('users');
      expect(rows, isA<List<Map<String, dynamic>>>());
      expect(rows, [
        {'id': 1, 'name': 'Ada'}
      ]);
    });

    test('same statement with different arguments does not match', () async {
      recorder.startRecording();
      await db.query('users', where: 'id = ?', whereArgs: [1]);
      final session = (await recorder.stopRecording())!;
      await recorder.startReplay(session.id);

      final baseline = inner.calls;
      await db.query('users', where: 'id = ?', whereArgs: [2]);
      expect(inner.calls, baseline + 1); // forwarded, not replayed
    });

    test('forwards unrecorded operations by default', () async {
      final session = await recordSession();
      await recorder.startReplay(session.id);

      final baseline = inner.calls;
      await db.delete('users', where: 'id = ?', whereArgs: [9]);
      expect(inner.calls, baseline + 1);
    });

    test('rejects unrecorded operations when configured to', () async {
      db = RecordingDatabaseAdapter(
        inner: inner,
        recorder: recorder,
        onReplayMiss: ReplayMissBehavior.reject,
      );
      final session = await recordSession();
      await recorder.startReplay(session.id);

      expect(
        () => db.delete('users', where: 'id = ?', whereArgs: [9]),
        throwsStateError,
      );
    });
  });

  group('raw operations and execute', () {
    test('record and replay like every other operation', () async {
      recorder.startRecording();
      final insertId =
          await db.rawInsert('INSERT INTO users (name) VALUES (?)', ['Grace']);
      final updated = await db.rawUpdate('UPDATE users SET name = ?', ['Ada']);
      final deleted = await db.rawDelete('DELETE FROM users WHERE id = ?', [1]);
      await db.execute('VACUUM');
      final session = (await recorder.stopRecording())!;
      expect(session.interactions.map((i) => i.request.operation),
          ['rawInsert', 'rawUpdate', 'rawDelete', 'execute']);

      await recorder.startReplay(session.id);
      final baseline = inner.calls;
      expect(
          await db.rawInsert('INSERT INTO users (name) VALUES (?)', ['Grace']),
          insertId);
      expect(await db.rawUpdate('UPDATE users SET name = ?', ['Ada']), updated);
      expect(
          await db.rawDelete('DELETE FROM users WHERE id = ?', [1]), deleted);
      await db.execute('VACUUM');
      expect(inner.calls, baseline);
    });
  });

  group('mixed sources', () {
    test('database traffic coexists with other sources in one session',
        () async {
      recorder.startRecording();
      await db.query('users');
      recorder.record(() => RecordedInteraction(
            request: RecordedRequest(
              source: 'http',
              operation: 'GET',
              target: '/users',
            ),
            response: 'http response',
            recordedAt: DateTime.now(),
          ));
      final session = (await recorder.stopRecording())!;
      await recorder.startReplay(session.id);

      final rows = await db.query('users');
      expect(rows, [
        {'id': 1, 'name': 'Ada'}
      ]);
      final decision = recorder.decide(() => RecordedRequest(
            source: 'http',
            operation: 'GET',
            target: '/users',
          ));
      expect((decision as Replayed).interaction.response, 'http response');
    });
  });
}
