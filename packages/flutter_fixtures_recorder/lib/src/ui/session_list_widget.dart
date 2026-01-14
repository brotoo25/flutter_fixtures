import 'package:flutter/material.dart';

import '../recorder/fixture_recorder.dart';
import '../storage/session_metadata.dart';

/// Dialog for selecting and managing recording sessions
///
/// Provides options to:
/// - Start a new recording
/// - Play back an existing session
/// - Delete sessions
class SessionSelectionDialog extends StatefulWidget {
  /// The recorder instance to interact with
  final FixtureRecorder recorder;

  /// Creates a session selection dialog
  const SessionSelectionDialog({
    super.key,
    required this.recorder,
  });

  @override
  State<SessionSelectionDialog> createState() => _SessionSelectionDialogState();
}

class _SessionSelectionDialogState extends State<SessionSelectionDialog> {
  List<SessionMetadata>? _sessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await widget.recorder.listSessions();
    setState(() => _sessions = sessions);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fixture Recorder'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Recording Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.recorder.startRecording();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Saved Sessions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Sessions List
            if (_sessions == null)
              const CircularProgressIndicator()
            else if (_sessions!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No saved sessions yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sessions!.length,
                  itemBuilder: (context, index) {
                    final session = _sessions![index];
                    return SessionListItem(
                      session: session,
                      onPlay: () {
                        widget.recorder.startPlayback(session.name);
                        Navigator.pop(context);
                      },
                      onDelete: () async {
                        await widget.recorder.deleteSession(session.name);
                        _loadSessions();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// List item displaying a single session with play and delete actions
class SessionListItem extends StatelessWidget {
  /// Session metadata to display
  final SessionMetadata session;

  /// Callback when play button is pressed
  final VoidCallback onPlay;

  /// Callback when delete button is pressed
  final VoidCallback onDelete;

  /// Creates a session list item
  const SessionListItem({
    super.key,
    required this.session,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lastUsed = session.lastUsedAt ?? session.createdAt;
    final formattedDate = _formatDate(lastUsed);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(session.name),
        subtitle: Text(
          '${session.eventCount} events • Last used: $formattedDate',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              onPressed: onPlay,
              tooltip: 'Play session',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
              tooltip: 'Delete session',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }
}
