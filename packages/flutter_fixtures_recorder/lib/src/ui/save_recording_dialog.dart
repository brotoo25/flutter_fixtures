import 'package:flutter/material.dart';

import '../fixture_recorder.dart';
import '../recording_session.dart';

/// Stops the recorder's recording the way the built-in toolbar does.
///
/// An empty recording stops without a prompt ("Nothing recorded."); otherwise
/// a dialog asks for a session name (blank means the recorder's timestamped
/// default) or to discard. Dismissing the dialog keeps the recording
/// running. Saves are confirmed with a snackbar naming the session.
///
/// Returns the saved session, or `null` when nothing was saved. Custom
/// control surfaces can call this directly instead of rebuilding the flow:
///
/// ```dart
/// IconButton(
///   icon: const Icon(Icons.stop),
///   onPressed: () => stopRecordingWithPrompt(context, recorder),
/// )
/// ```
Future<RecordingSession?> stopRecordingWithPrompt(
  BuildContext context,
  FixtureRecorder recorder,
) async {
  // This only decides whether to show the name prompt; the recorder owns
  // the "empty recording saves nothing" rule.
  if (recorder.recordedCount == 0) {
    await recorder.stopRecording();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing recorded.')),
      );
    }
    return null;
  }
  final choice = await showDialog<_StopChoice>(
    context: context,
    builder: (context) => const _SaveRecordingDialog(),
  );
  // Dismissing the dialog (barrier tap / back) keeps the recording running.
  if (choice == null) return null;
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
  return session;
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
