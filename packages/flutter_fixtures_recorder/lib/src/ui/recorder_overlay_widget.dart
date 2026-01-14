import 'package:flutter/material.dart';

import '../core/recorder_mode.dart';
import '../recorder/fixture_recorder.dart';
import 'recording_status_indicator.dart';
import 'session_list_widget.dart';

/// Floating overlay widget with record/play/stop button
///
/// This widget provides a FAB-style button that changes behavior based on
/// the current recorder mode:
/// - Idle: Shows session selection dialog
/// - Recording: Shows save recording dialog
/// - Playback: Stops playback
///
/// The overlay can be conditionally hidden based on mock mode settings.
class RecorderOverlayWidget extends StatelessWidget {
  /// The recorder instance to control
  final FixtureRecorder recorder;

  /// Whether to only show the overlay when in mock mode
  ///
  /// Defaults to true, meaning the overlay is hidden in production.
  final bool showOnlyInMockMode;

  /// Whether the app is currently in mock mode
  ///
  /// When [showOnlyInMockMode] is true, the overlay only appears when
  /// this is true.
  final bool isMockMode;

  /// Creates a recorder overlay widget
  const RecorderOverlayWidget({
    super.key,
    required this.recorder,
    this.showOnlyInMockMode = true,
    this.isMockMode = true,
  });

  @override
  Widget build(BuildContext context) {
    if (showOnlyInMockMode && !isMockMode) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        return Positioned(
          right: 16,
          bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecordingStatusIndicator(mode: recorder.mode),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () => _handleAction(context),
                backgroundColor: _getButtonColor(),
                child: _getButtonIcon(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAction(BuildContext context) {
    switch (recorder.mode) {
      case RecorderMode.idle:
        _showSessionSelectionDialog(context);
        break;
      case RecorderMode.recording:
        _showSaveRecordingDialog(context);
        break;
      case RecorderMode.playback:
        recorder.stopPlayback();
        break;
    }
  }

  Color _getButtonColor() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return Colors.blue;
      case RecorderMode.recording:
        return Colors.red;
      case RecorderMode.playback:
        return Colors.green;
    }
  }

  Icon _getButtonIcon() {
    switch (recorder.mode) {
      case RecorderMode.idle:
        return const Icon(Icons.fiber_manual_record);
      case RecorderMode.recording:
        return const Icon(Icons.stop);
      case RecorderMode.playback:
        return const Icon(Icons.stop);
    }
  }

  Future<void> _showSessionSelectionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => SessionSelectionDialog(recorder: recorder),
    );
  }

  Future<void> _showSaveRecordingDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            hintText: 'Enter session name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              recorder.cancelRecording();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await recorder.stopRecording(result);
    }
  }
}
