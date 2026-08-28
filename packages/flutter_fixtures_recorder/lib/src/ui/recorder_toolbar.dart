import 'package:flutter/material.dart';

import '../fixture_recorder.dart';
import 'session_list_sheet.dart';

/// The built-in control surface for a [FixtureRecorder].
///
/// Shows the recorder's current state and offers the matching actions:
/// start recording, stop (with a save-or-discard prompt), stop replay, and
/// open the saved-sessions sheet. Drop it anywhere in a debug or demo build:
///
/// ```dart
/// RecorderToolbar(recorder: recorder)
/// ```
///
/// This widget is a plain listener on [FixtureRecorder] — a custom control
/// surface needs nothing beyond the recorder's public API.
class RecorderToolbar extends StatelessWidget {
  /// The recorder this toolbar controls.
  final FixtureRecorder recorder;

  const RecorderToolbar({super.key, required this.recorder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusIcon(theme),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 4),
                ..._actions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusIcon(ThemeData theme) {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return Icon(Icons.radio_button_unchecked,
            size: 18, color: theme.colorScheme.outline);
      case RecorderMode.recording:
        return const Icon(Icons.fiber_manual_record,
            size: 18, color: Colors.red);
      case RecorderMode.replaying:
        return Icon(Icons.play_circle,
            size: 18, color: theme.colorScheme.primary);
    }
  }

  String _statusLabel() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return 'Recorder idle';
      case RecorderMode.recording:
        return 'Recording · ${recorder.recordedCount}';
      case RecorderMode.replaying:
        return 'Replaying "${recorder.replaySession?.name}"';
    }
  }

  List<Widget> _actions(BuildContext context) {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return [
          IconButton(
            tooltip: 'Start recording',
            icon: const Icon(Icons.fiber_manual_record),
            color: Colors.red,
            onPressed: recorder.startRecording,
          ),
          IconButton(
            tooltip: 'Recorded sessions',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => showRecordingSessionsSheet(context, recorder),
          ),
        ];
      case RecorderMode.recording:
        return [
          IconButton(
            tooltip: 'Stop recording',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () => _stopRecording(context),
          ),
        ];
      case RecorderMode.replaying:
        return [
          IconButton(
            tooltip: 'Restart replay',
            icon: const Icon(Icons.replay),
            onPressed: recorder.restartReplay,
          ),
          IconButton(
            tooltip: 'Stop replay',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: recorder.stopReplay,
          ),
          IconButton(
            tooltip: 'Recorded sessions',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => showRecordingSessionsSheet(context, recorder),
          ),
        ];
    }
  }

  Future<void> _stopRecording(BuildContext context) async {
    if (recorder.recordedCount == 0) {
      await recorder.stopRecording(discard: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing recorded.')),
        );
      }
      return;
    }
    final choice = await showDialog<_StopChoice>(
      context: context,
      builder: (context) => const _SaveRecordingDialog(),
    );
    // Dismissing the dialog (barrier tap / back) keeps the recording running.
    if (choice == null) return;
    // A blank name means "use the default" — the recorder owns that rule.
    final session = await recorder.stopRecording(
      name: choice.name,
      discard: choice.discard,
    );
    if (session != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${session.name}".')),
      );
    }
  }
}

class _StopChoice {
  final String? name;
  final bool discard;

  const _StopChoice.save(this.name) : discard = false;
  const _StopChoice.discard()
      : name = null,
        discard = true;
}

class _SaveRecordingDialog extends StatefulWidget {
  const _SaveRecordingDialog();

  @override
  State<_SaveRecordingDialog> createState() => _SaveRecordingDialogState();
}

class _SaveRecordingDialogState extends State<_SaveRecordingDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save recording'),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Session name',
          hintText: 'Leave empty for a timestamped name',
        ),
        onSubmitted: (value) => Navigator.pop(context, _StopChoice.save(value)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const _StopChoice.discard()),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _StopChoice.save(_name.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
