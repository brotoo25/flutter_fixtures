import 'package:flutter/material.dart';

import '../fixture_recorder.dart';
import '../recording_session.dart';

/// Shows the built-in saved-sessions sheet for a [FixtureRecorder].
///
/// Lists saved sessions newest first; tapping one starts replaying it
/// (switching sessions if a replay is already active), and the trash icon
/// deletes it. Like the toolbar, this is a plain consumer of the recorder's
/// public API — replace it freely with your own session picker.
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

class _SessionListSheetState extends State<_SessionListSheet> {
  late Future<List<RecordingSession>> _sessions;

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
      child: FutureBuilder<List<RecordingSession>>(
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
              for (final session in sessions)
                ListTile(
                  leading: widget.recorder.replaySession?.id == session.id
                      ? const Icon(Icons.play_circle)
                      : const Icon(Icons.movie_outlined),
                  title: Text(session.name),
                  subtitle: Text(
                    '${session.interactions.length} interactions',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete session',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.recorder.deleteSession(session.id);
                      _reload();
                    },
                  ),
                  onTap: () => _replay(session),
                ),
            ],
          );
        },
      ),
    );
  }

  void _replay(RecordingSession session) {
    if (widget.recorder.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop the recording first.')),
      );
      return;
    }
    widget.recorder.stopReplay();
    widget.recorder.startReplayOf(session);
    Navigator.pop(context);
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
