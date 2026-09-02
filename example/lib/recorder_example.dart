import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_fixtures/flutter_fixtures.dart';
import 'package:flutter_fixtures_recorder/flutter_fixtures_recorder.dart';
import 'package:path_provider/path_provider.dart';

/// Demonstrates the recorder module composed with the fixtures pipeline:
/// every request's response is chosen through flutter_fixtures itself
/// (the pick dialog), the recorder captures whichever responses you
/// choose, and replaying serves them back instantly — same choices, same
/// order, no dialogs.
///
/// The screen is three blocks: a status card that is also the control
/// surface (and, while replaying, the session's live progress), a row of
/// request chips, and a full-height request log whose rows open their
/// response body in a bottom sheet. The status card is a custom control
/// surface built on the recorder's public API; the built-in sessions
/// sheet is used as-is.
class RecorderExamplePage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  /// Increments when the app bar's clear action is tapped on this tab;
  /// the page clears its request log in response.
  final ValueListenable<int>? clearSignal;

  const RecorderExamplePage({
    super.key,
    required this.navigatorKey,
    this.clearSignal,
  });

  @override
  State<RecorderExamplePage> createState() => _RecorderExamplePageState();
}

enum _Provenance { fixture, recorded, replayed }

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
  // hand through the library's own pick dialog. Replay misses forward:
  // once a session's recordings for a request run out, the request falls
  // back to the fixtures pipeline and the picker explicitly returns —
  // unless that pick was marked "Remember", which answers silently.
  late final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..interceptors.add(RecorderInterceptor(recorder: recorder))
    ..interceptors.add(FixturesInterceptor(
      dataSelectorView: FixturesDialogView(
        contextProvider: () => widget.navigatorKey.currentContext!,
      ),
      dataSelector: DataSelectorType.pick,
    ));

  final List<_LogEntry> _log = [];
  bool _hasSessions = false;
  bool _timelineExpanded = true;

  @override
  void initState() {
    super.initState();
    recorder.addListener(_onRecorderChanged);
    widget.clearSignal?.addListener(_clearLog);
    _refreshSessions();
  }

  @override
  void dispose() {
    recorder.removeListener(_onRecorderChanged);
    widget.clearSignal?.removeListener(_clearLog);
    super.dispose();
  }

  void _clearLog() {
    if (_log.isEmpty) return;
    setState(_log.clear);
  }

  // The recorder notifies on mode changes, captures, and replayed hits —
  // the timeline reads its progress straight off the recorder.
  void _onRecorderChanged() {
    setState(() {});
    // Stopping a recording notifies once the session is saved.
    if (recorder.mode == RecorderMode.idle) _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    final sessions = await recorder.sessions();
    if (mounted) setState(() => _hasSessions = sessions.isNotEmpty);
  }

  Future<void> _request(
    String method,
    String pathAndQuery,
    Future<Response> Function() send,
  ) async {
    final stopwatch = Stopwatch()..start();
    _LogEntry entry;
    try {
      entry = _entryFor(method, pathAndQuery, await send(), stopwatch);
    } on DioException catch (e) {
      // Error statuses (recorded or replayed) arrive here with a response;
      // rejected requests (pick dialog cancelled, replay miss) without one.
      final response = e.response;
      if (response != null) {
        entry = _entryFor(method, pathAndQuery, response, stopwatch);
      } else {
        stopwatch.stop();
        final cancelled = '${e.error}'.contains('No fixture selected');
        entry = _LogEntry(
          method: method,
          path: pathAndQuery,
          status: cancelled ? 'cancelled' : 'error',
          milliseconds: stopwatch.elapsedMilliseconds,
          provenance:
              recorder.isRecording ? _Provenance.recorded : _Provenance.fixture,
          body: cancelled
              ? 'Pick dialog cancelled — no response was chosen.'
              : '${e.error}',
        );
      }
    }
    setState(() => _log.insert(0, entry));
  }

  _LogEntry _entryFor(
    String method,
    String pathAndQuery,
    Response response,
    Stopwatch stopwatch,
  ) {
    stopwatch.stop();
    // Replayed responses are tagged by the interceptor; anything else came
    // through the fixtures pipeline (captured while recording).
    final replayed =
        response.headers.value(RecorderInterceptor.replayedHeader) != null;
    return _LogEntry(
      method: method,
      path: pathAndQuery,
      status: '${response.statusCode}',
      milliseconds: stopwatch.elapsedMilliseconds,
      provenance: replayed
          ? _Provenance.replayed
          : recorder.isRecording
              ? _Provenance.recorded
              : _Provenance.fixture,
      body: _prettifyJson(response.data),
    );
  }

  String _prettifyJson(dynamic data) {
    try {
      if (data is String) data = jsonDecode(data);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  void _showEntry(_LogEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ProvenanceChip(provenance: entry.provenance),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${entry.method} ${entry.path}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.status} · ${entry.milliseconds} ms',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        entry.body,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- build ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StatusCard(
            recorder: recorder,
            hasSessions: _hasSessions,
            timelineExpanded: _timelineExpanded,
            onToggleTimeline: () =>
                setState(() => _timelineExpanded = !_timelineExpanded),
            onRecord: recorder.startRecording,
            onStopRecording: () => stopRecordingWithPrompt(context, recorder),
            onStopReplay: recorder.stopReplay,
            onRestartReplay: recorder.restartReplay,
            onSessions: () => showRecordingSessionsSheet(context, recorder),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _requestChip(Icons.login, 'POST /login', () {
                  _request(
                      'POST',
                      '/login',
                      () => dio.post('/login', data: {
                            'username': 'admin',
                            'password': '123456',
                          }));
                }),
                const SizedBox(width: 8),
                _requestChip(Icons.monitor_heart, 'GET /health', () {
                  _request('GET', '/health', () => dio.get('/health'));
                }),
                const SizedBox(width: 8),
                _requestChip(Icons.search, 'GET /search', () {
                  _request(
                      'GET',
                      '/search?page=1&q=flutter',
                      () => dio.get('/search', queryParameters: {
                            'page': '1',
                            'q': 'flutter',
                          }));
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildLog(context)),
        ],
      ),
    );
  }

  Widget _requestChip(IconData icon, String label, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: _log.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = _log[index];
          return ListTile(
            dense: true,
            leading: _ProvenanceChip(provenance: entry.provenance),
            title: Text('${entry.method} ${entry.path}',
                overflow: TextOverflow.ellipsis),
            trailing: Text(
              '${entry.status} · ${entry.milliseconds} ms',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            onTap: () => _showEntry(entry),
          );
        },
      ),
    );
  }
}

/// The one control surface: mode color, next-step hint, actions — and,
/// while replaying, the session's live progress with a collapsible
/// timeline. A custom surface needs nothing beyond the recorder's public
/// API — progress included.
class _StatusCard extends StatelessWidget {
  final FixtureRecorder recorder;
  final bool hasSessions;
  final bool timelineExpanded;
  final VoidCallback onToggleTimeline;
  final VoidCallback onRecord;
  final VoidCallback onStopRecording;
  final VoidCallback onStopReplay;
  final VoidCallback onRestartReplay;
  final VoidCallback onSessions;

  const _StatusCard({
    required this.recorder,
    required this.hasSessions,
    required this.timelineExpanded,
    required this.onToggleTimeline,
    required this.onRecord,
    required this.onStopRecording,
    required this.onStopReplay,
    required this.onRestartReplay,
    required this.onSessions,
  });

  @override
  Widget build(BuildContext context) {
    final session = recorder.replaySession;
    final (color, onColor, icon, title, hint) = switch (recorder.mode) {
      RecorderMode.recording => (
          Colors.red[50]!,
          Colors.red[900]!,
          Icons.fiber_manual_record,
          'Recording · ${recorder.recordedCount}',
          'Every response you pick is captured.',
        ),
      RecorderMode.replaying => (
          Colors.green[50]!,
          Colors.green[900]!,
          Icons.replay_circle_filled,
          'Replaying "${session?.name}"',
          'Recorded choices return in order; when they run out, the '
              'picker returns (remembered picks answer silently).',
        ),
      RecorderMode.idle => (
          Colors.blueGrey[50]!,
          Colors.blueGrey[800]!,
          Icons.rule,
          'Fixtures — you pick each response',
          hasSessions
              ? 'Replay saved choices, or record new ones.'
              : 'Record while picking — your choices become a session.',
        ),
    };

    final actions = switch (recorder.mode) {
      RecorderMode.idle => [
          IconButton.filled(
            tooltip: 'Start recording',
            style: IconButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.fiber_manual_record, size: 20),
            onPressed: onRecord,
          ),
          IconButton(
            tooltip: 'Sessions',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: onSessions,
          ),
        ],
      RecorderMode.recording => [
          IconButton.filled(
            tooltip: 'Stop and save',
            icon: const Icon(Icons.stop, size: 20),
            onPressed: onStopRecording,
          ),
        ],
      RecorderMode.replaying => [
          IconButton(
            tooltip: 'Restart replay',
            icon: const Icon(Icons.replay),
            onPressed: onRestartReplay,
          ),
          IconButton(
            tooltip: 'Stop replay',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: onStopReplay,
          ),
          IconButton(
            tooltip: 'Sessions',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: onSessions,
          ),
        ],
    };

    final total = session?.interactions.length ?? 0;
    final served = recorder.replayedCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: onColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: onColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(hint,
                        style: TextStyle(
                            color: onColor.withValues(alpha: 0.85),
                            fontSize: 12)),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (recorder.isReplaying && session != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: onToggleTimeline,
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : served / total,
                          minHeight: 6,
                          color: Colors.green,
                          backgroundColor: Colors.green[100],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$served / $total',
                        style: TextStyle(color: onColor, fontSize: 12)),
                    Icon(
                      timelineExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: onColor,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: timelineExpanded
                  ? _TimelineList(
                      session: session,
                      serveOrder: recorder.replayServeOrder,
                      onColor: onColor,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// The session's interactions in recorded order, checked off live with
/// serve-order badges as replayed requests consume them. Each serves
/// exactly once — a full timeline means the session's scope has ended
/// and further requests go back to the fixtures picker.
class _TimelineList extends StatelessWidget {
  final RecordingSession session;
  final List<int?> serveOrder;
  final Color onColor;

  const _TimelineList({
    required this.session,
    required this.serveOrder,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 132),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 6, right: 8),
        itemCount: session.interactions.length,
        itemBuilder: (context, index) {
          final interaction = session.interactions[index];
          final order = serveOrder[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                order == null
                    ? Icon(Icons.radio_button_unchecked,
                        size: 16, color: Colors.green[200])
                    : CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.green,
                        child: Text('$order',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${interaction.request.operation} '
                    '${interaction.request.target}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: order == null
                          ? onColor.withValues(alpha: 0.5)
                          : onColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// FIXTURE / REC / REPLAY — where a response came from.
class _ProvenanceChip extends StatelessWidget {
  final _Provenance provenance;

  const _ProvenanceChip({required this.provenance});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (provenance) {
      _Provenance.fixture => ('FIXTURE', Colors.blueGrey),
      _Provenance.recorded => ('REC', Colors.red),
      _Provenance.replayed => ('REPLAY', Colors.green),
    };
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
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
