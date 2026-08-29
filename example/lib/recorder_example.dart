import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:path_provider/path_provider.dart';

/// Demonstrates the recorder module composed with the fixtures pipeline:
/// every request's response is chosen through flutter_fixtures itself
/// (the pick dialog), the recorder captures whichever responses you
/// choose, and replaying serves them back instantly — same choices, same
/// order, no dialogs, no network.
///
/// Every request lands in a log with a provenance chip (FIXTURE / REC /
/// REPLAY / MISS) and its latency, and while replaying a session timeline
/// checks recorded interactions off in serve order.
class RecorderExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const RecorderExamplePage({super.key, required this.navigatorKey});

  @override
  State<RecorderExamplePage> createState() => _RecorderExamplePageState();
}

enum _Provenance { fixture, recorded, replayed, miss }

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

  // The recorder interceptor comes first, so replayed sessions win and
  // recording sees the fixture-served responses. The fixtures interceptor
  // serves every request from fixture files, with the response chosen by
  // hand through the library's own pick dialog. Replay misses reject, so
  // while replaying nothing falls through to the fixture pipeline.
  late final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..interceptors.add(RecorderInterceptor(
      recorder: recorder,
      onReplayMiss: ReplayMissBehavior.reject,
    ))
    ..interceptors.add(FixturesInterceptor(
      dataSelectorView: FixturesDialogView(
        contextProvider: () => widget.navigatorKey.currentContext!,
      ),
      dataSelector: DataSelectorType.pick,
    ));

  final List<_LogEntry> _log = [];
  int _selected = 0;
  bool _hasSessions = false;

  // Mirror of the replay cursor, so the timeline can check interactions
  // off in serve order. Reset whenever the recorder notifies while
  // replaying (replay start, session switch, or restart — decide() and
  // lookups never notify).
  final Map<String, int> _cursorByKey = {};
  final Map<int, int> _serveOrder = {};
  final Map<int, int> _repeats = {};
  int _serveCounter = 0;

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
    setState(() {
      if (recorder.isReplaying) _resetMirror();
    });
    // Stopping a recording may have saved a new session.
    if (recorder.mode == RecorderMode.idle) _refreshSessions();
  }

  void _resetMirror() {
    _cursorByKey.clear();
    _serveOrder.clear();
    _repeats.clear();
    _serveCounter = 0;
  }

  Future<void> _refreshSessions() async {
    final sessions = await recorder.sessions();
    if (mounted) setState(() => _hasSessions = sessions.isNotEmpty);
  }

  /// The replay match key for a request — the same identity the recorder
  /// uses: method plus core's canonical target rendering.
  String _keyFor(String method, String pathAndQuery) {
    final request = HttpFixtureRequest.fromUri(method, Uri.parse(pathAndQuery));
    return '${request.method} ${request.canonicalTarget}';
  }

  String _keyOfInteraction(RecordedInteraction interaction) {
    return '${interaction.request.operation} ${interaction.request.target}';
  }

  /// Advance the mirrored cursor for a replayed request: mark the next
  /// unconsumed recording for this key served, or count a repeat once the
  /// key is exhausted (the engine repeats the last recording).
  void _markConsumed(String method, String pathAndQuery) {
    final session = recorder.replaySession;
    if (session == null) return;
    final key = _keyFor(method, pathAndQuery);
    final indices = [
      for (var i = 0; i < session.interactions.length; i++)
        if (_keyOfInteraction(session.interactions[i]) == key) i,
    ];
    if (indices.isEmpty) return;
    final cursor = _cursorByKey[key] ?? 0;
    if (cursor < indices.length) {
      _serveOrder[indices[cursor]] = ++_serveCounter;
    } else {
      _repeats[indices.last] = (_repeats[indices.last] ?? 0) + 1;
    }
    _cursorByKey[key] = cursor + 1;
  }

  Future<void> _request(
    String method,
    String pathAndQuery,
    Future<Response> Function() send,
  ) async {
    final provenance = switch (recorder.mode) {
      RecorderMode.replaying => _Provenance.replayed,
      RecorderMode.recording => _Provenance.recorded,
      RecorderMode.idle => _Provenance.fixture,
    };
    final stopwatch = Stopwatch()..start();
    _LogEntry entry;
    try {
      final response = await send();
      stopwatch.stop();
      entry = _LogEntry(
        method: method,
        path: pathAndQuery,
        status: '${response.statusCode}',
        milliseconds: stopwatch.elapsedMilliseconds,
        provenance: provenance,
        body: _prettifyJson(response.data),
      );
      if (provenance == _Provenance.replayed) {
        _markConsumed(method, pathAndQuery);
      }
    } catch (e) {
      stopwatch.stop();
      final isMiss = recorder.isReplaying;
      final cancelled = !isMiss && '$e'.contains('No fixture selected');
      entry = _LogEntry(
        method: method,
        path: pathAndQuery,
        status: isMiss ? 'miss' : (cancelled ? 'cancelled' : 'error'),
        milliseconds: stopwatch.elapsedMilliseconds,
        provenance: isMiss ? _Provenance.miss : provenance,
        body: isMiss
            ? 'Not in this session — while replaying, requests never fall '
                'through to the fixture pipeline.\n\nReplay matches '
                'method + path + query, so a request you did not record '
                'is a miss.\n\n$e'
            : cancelled
                ? 'Pick dialog cancelled — no response was chosen.'
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
    final session = recorder.replaySession;
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
          if (recorder.isReplaying && session != null) ...[
            const SizedBox(height: 12),
            _SessionTimeline(
              session: session,
              serveOrder: _serveOrder,
              repeats: _repeats,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _requestButton(
                  Icons.login,
                  'POST /login',
                  () => _request(
                      'POST',
                      '/login',
                      () => dio.post('/login', data: {
                            'username': 'admin',
                            'password': '123456',
                          }))),
              _requestButton(Icons.monitor_heart, 'GET /health',
                  () => _request('GET', '/health', () => dio.get('/health'))),
              _requestButton(
                  Icons.search,
                  'GET /search',
                  () => _request(
                      'GET',
                      '/search?page=1&q=flutter',
                      () => dio.get('/search', queryParameters: {
                            'page': '1',
                            'q': 'flutter',
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
          'No requests yet.\nFire one above and pick its response in the '
          'fixtures dialog.',
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
          'Fire requests and pick their responses; every choice is '
              'captured. Tap ⏹ in the toolbar to save the session.',
        ),
      RecorderMode.replaying => (
          Colors.green[50]!,
          Colors.green[900]!,
          Icons.replay_circle_filled,
          'REPLAYING "${recorder.replaySession?.name}"',
          'Fire the same requests: your recorded choices return instantly, '
              'in order, with no dialogs — watch the timeline below.',
        ),
      RecorderMode.idle => (
          Colors.blueGrey[50]!,
          Colors.blueGrey[800]!,
          Icons.rule,
          'FIXTURES — you pick each response',
          hasSessions
              ? 'Tap the sessions icon in the toolbar to replay saved '
                  'choices — or record a new session with ⏺.'
              : 'Tap ⏺ in the toolbar, fire requests, and pick their '
                  'responses — your choices become a replayable session.',
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

/// The active session's interactions in recorded order, checked off live
/// as replayed requests consume them — the per-key replay cursor, made
/// visible. A ↻ badge appears when an exhausted recording repeats its
/// last response.
class _SessionTimeline extends StatelessWidget {
  final RecordingSession session;
  final Map<int, int> serveOrder;
  final Map<int, int> repeats;

  const _SessionTimeline({
    required this.session,
    required this.serveOrder,
    required this.repeats,
  });

  @override
  Widget build(BuildContext context) {
    final served = serveOrder.length;
    final total = session.interactions.length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Session timeline — $served of $total served',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.green[900]),
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: session.interactions.length,
                itemBuilder: (context, index) {
                  final interaction = session.interactions[index];
                  final order = serveOrder[index];
                  final repeatCount = repeats[index] ?? 0;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: order == null
                        ? Icon(Icons.radio_button_unchecked,
                            size: 20, color: Colors.grey[400])
                        : CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.green,
                            child: Text('$order',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          ),
                    title: Text(
                      '${interaction.request.operation} '
                      '${interaction.request.target}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: order == null ? Colors.grey[600] : null,
                      ),
                    ),
                    trailing: repeatCount > 0
                        ? Text('↻ ×$repeatCount',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green[800]))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FIXTURE / REC / REPLAY / MISS — where a response came from.
class _ProvenanceChip extends StatelessWidget {
  final _Provenance provenance;

  const _ProvenanceChip({required this.provenance});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (provenance) {
      _Provenance.fixture => ('FIXTURE', Colors.blueGrey),
      _Provenance.recorded => ('REC', Colors.red),
      _Provenance.replayed => ('REPLAY', Colors.green),
      _Provenance.miss => ('MISS', Colors.orange),
    };
    return Container(
      width: 62,
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
