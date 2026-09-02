import 'package:flutter/material.dart';

import '../fixture_recorder.dart';
import '../recording_session.dart';

/// Shows the built-in saved-sessions sheet for a [FixtureRecorder].
///
/// Lists session summaries newest first (recorded payloads are never
/// loaded for the listing); tapping one starts replaying it (switching
/// sessions if a replay is already active), and the trash icon deletes it
/// — stopping the replay first if that session is the one being replayed.
/// Like the toolbar, this is a plain consumer of the recorder's public
/// API — replace it freely with your own session picker.
Future<void> showRecordingSessionsSheet(
  BuildContext context,
  FixtureRecorder recorder,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SessionListSheet(recorder: recorder),
  );
}

class _SessionListSheet extends StatefulWidget {
  final FixtureRecorder recorder;

  const _SessionListSheet({required this.recorder});

  @override
  State<_SessionListSheet> createState() => _SessionListSheetState();
}

// Reading recorder state without a ListenableBuilder is safe here only
// because every state-changing action either pops the sheet or reloads it.
class _SessionListSheetState extends State<_SessionListSheet> {
  late Future<List<RecordingSessionSummary>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = widget.recorder.sessions();
  }

  void _reload() {
    final refreshed = widget.recorder.sessions();
    setState(() {
      _sessions = refreshed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<RecordingSessionSummary>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message('Could not load sessions: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return _message('No recorded sessions yet.\n'
                'Start a recording and exercise the app to create one.');
          }
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'Recorded sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: widget.recorder.isReplaying
                    ? TextButton(
                        onPressed: () {
                          widget.recorder.stopReplay();
                          Navigator.pop(context);
                        },
                        child: const Text('Stop replay'),
                      )
                    : null,
              ),
              for (final summary in sessions)
                ListTile(
                  leading: widget.recorder.replaySession?.id == summary.id
                      ? const Icon(Icons.play_circle)
                      : const Icon(Icons.movie_outlined),
                  title: Text(summary.name),
                  subtitle: Text(
                    '${summary.interactionCount} interactions',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete session',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(summary),
                  ),
                  onTap: () => _replay(summary),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(RecordingSessionSummary summary) async {
    // A replay must not outlive its session.
    if (widget.recorder.replaySession?.id == summary.id) {
      widget.recorder.stopReplay();
    }
    await widget.recorder.deleteSession(summary.id);
    if (mounted) _reload();
  }

  Future<void> _replay(RecordingSessionSummary summary) async {
    // Loads current state from the store; switching sessions while
    // replaying is the recorder's job, not this widget's.
    await widget.recorder.startReplay(summary.id);
    if (mounted) Navigator.pop(context);
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
