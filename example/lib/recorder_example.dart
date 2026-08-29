import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:path_provider/path_provider.dart';

/// Demonstrates the recorder module: capture real traffic from
/// jsonplaceholder.typicode.com, save it as a named session, then replay it
/// with networking cut off — the flow used for product demos and offline
/// simulations.
///
/// Every request lands in a log with a provenance chip (LIVE / REC /
/// REPLAY / MISS) and its latency, so where a response came from is
/// visible at a glance — replayed responses return in ~0 ms.
class RecorderExamplePage extends StatefulWidget {
  const RecorderExamplePage({super.key});

  @override
  State<RecorderExamplePage> createState() => _RecorderExamplePageState();
}

enum _Provenance { live, recorded, replayed, miss }

class _LogEntry {
  final String method;
  final String path;
  final String status;
  final int milliseconds;
  final _Provenance provenance;
  final String body;

  _LogEntry({
    required this.method,
    required this.path,
    required this.status,
    required this.milliseconds,
    required this.provenance,
    required this.body,
  });
}

class _RecorderExamplePageState extends State<RecorderExamplePage> {
  // sessionStoreForDirectory resolves the directory lazily and falls back
  // to an in-memory store on web, so everything constructs synchronously.
  late final FixtureRecorder recorder = FixtureRecorder(
    store: sessionStoreForDirectory(() async =>
        '${(await getApplicationDocumentsDirectory()).path}/fixture_recordings'),
  );

  // Reject replay misses: while replaying, the network is provably never
  // touched — an unrecorded request fails as MISS instead of going online.
  late final Dio dio = Dio(
    BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'),
  )..interceptors.add(RecorderInterceptor(
      recorder: recorder,
      onReplayMiss: ReplayMissBehavior.reject,
    ));

  final List<_LogEntry> _log = [];
  int _selected = 0;
  bool _hasSessions = false;

  @override
  void initState() {
    super.initState();
    recorder.addListener(_onRecorderChanged);
    _refreshSessions();
  }

  @override
  void dispose() {
    recorder.removeListener(_onRecorderChanged);
    super.dispose();
  }

  void _onRecorderChanged() {
    setState(() {});
    // Stopping a recording may have saved a new session.
    if (recorder.mode == RecorderMode.idle) _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    final sessions = await recorder.sessions();
    if (mounted) setState(() => _hasSessions = sessions.isNotEmpty);
  }

  Future<void> _request(
    String method,
    String path,
    Future<Response> Function() send,
  ) async {
    final provenance = switch (recorder.mode) {
      RecorderMode.replaying => _Provenance.replayed,
      RecorderMode.recording => _Provenance.recorded,
      RecorderMode.idle => _Provenance.live,
    };
    final stopwatch = Stopwatch()..start();
    _LogEntry entry;
    try {
      final response = await send();
      stopwatch.stop();
      entry = _LogEntry(
        method: method,
        path: path,
        status: '${response.statusCode}',
        milliseconds: stopwatch.elapsedMilliseconds,
        provenance: provenance,
        body: _prettifyJson(response.data),
      );
    } catch (e) {
      stopwatch.stop();
      final isMiss = recorder.isReplaying;
      entry = _LogEntry(
        method: method,
        path: path,
        status: isMiss ? 'miss' : 'error',
        milliseconds: stopwatch.elapsedMilliseconds,
        provenance: isMiss ? _Provenance.miss : provenance,
        body: isMiss
            ? 'Not in this session — while replaying, the network is never '
                'touched.\n\n$e'
            : '$e',
      );
    }
    setState(() {
      _log.insert(0, entry);
      _selected = 0;
    });
  }

  String _prettifyJson(dynamic data) {
    try {
      if (data is String) data = jsonDecode(data);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: [
              RecorderToolbar(recorder: recorder),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          _ModeBanner(recorder: recorder, hasSessions: _hasSessions),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _requestButton(Icons.download, 'GET /todos/1',
                  () => _request('GET', '/todos/1', () => dio.get('/todos/1'))),
              _requestButton(
                  Icons.people,
                  'GET /users',
                  () => _request(
                      'GET',
                      '/users?_limit=3',
                      () =>
                          dio.get('/users', queryParameters: {'_limit': '3'}))),
              _requestButton(
                  Icons.upload,
                  'POST /posts',
                  () => _request(
                      'POST',
                      '/posts',
                      () => dio.post('/posts', data: {
                            'title': 'Recorded post',
                            'body': 'Captured by flutter_fixtures_recorder',
                            'userId': 1,
                          }))),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildLog(context)),
        ],
      ),
    );
  }

  Widget _requestButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildLog(BuildContext context) {
    if (_log.isEmpty) {
      return Center(
        child: Text(
          'No requests yet.\nFire one above to see where its response '
          'comes from.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    final selected = _log[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Request log: newest first, one provenance chip per request.
        Expanded(
          flex: 2,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListView.builder(
              itemCount: _log.length,
              itemBuilder: (context, index) {
                final entry = _log[index];
                return ListTile(
                  dense: true,
                  selected: index == _selected,
                  leading: _ProvenanceChip(provenance: entry.provenance),
                  title: Text('${entry.method} ${entry.path}'),
                  trailing: Text(
                    '${entry.status} · ${entry.milliseconds} ms',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  onTap: () => setState(() => _selected = index),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Body of the selected log entry.
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SingleChildScrollView(
              child: Text(
                selected.body,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A colored banner that mirrors the recorder's mode and says what to do
/// next — the state machine, made visible.
class _ModeBanner extends StatelessWidget {
  final FixtureRecorder recorder;
  final bool hasSessions;

  const _ModeBanner({required this.recorder, required this.hasSessions});

  @override
  Widget build(BuildContext context) {
    final (color, onColor, icon, title, hint) = switch (recorder.mode) {
      RecorderMode.recording => (
          Colors.red[50]!,
          Colors.red[900]!,
          Icons.fiber_manual_record,
          'RECORDING — ${recorder.recordedCount} captured',
          'Fire requests below; each live response is captured. '
              'Tap ⏹ in the toolbar to save the session.',
        ),
      RecorderMode.replaying => (
          Colors.green[50]!,
          Colors.green[900]!,
          Icons.replay_circle_filled,
          'REPLAYING "${recorder.replaySession?.name}"',
          'Fire the same requests: responses return instantly from the '
              'session, in recorded order. The network is never touched — '
              'Airplane Mode works.',
        ),
      RecorderMode.idle => (
          Colors.blueGrey[50]!,
          Colors.blueGrey[800]!,
          Icons.wifi,
          'LIVE — talking to jsonplaceholder.typicode.com',
          hasSessions
              ? 'Tap the sessions icon in the toolbar to replay a saved '
                  'session — or record a new one with ⏺.'
              : 'Tap ⏺ in the toolbar to start recording, then fire some '
                  'requests.',
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: onColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: onColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(hint, style: TextStyle(color: onColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// LIVE / REC / REPLAY / MISS — where a response came from.
class _ProvenanceChip extends StatelessWidget {
  final _Provenance provenance;

  const _ProvenanceChip({required this.provenance});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (provenance) {
      _Provenance.live => ('LIVE', Colors.blueGrey),
      _Provenance.recorded => ('REC', Colors.red),
      _Provenance.replayed => ('REPLAY', Colors.green),
      _Provenance.miss => ('MISS', Colors.orange),
    };
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.shade800,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
