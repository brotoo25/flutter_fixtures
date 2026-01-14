import 'package:flutter/material.dart';

import '../core/recorder_mode.dart';

/// Visual indicator showing the current recorder mode
///
/// Displays a badge with the current mode:
/// - "RECORDING" with pulsing dot when recording
/// - "PLAYING" when in playback mode
/// - Hidden when idle
class RecordingStatusIndicator extends StatelessWidget {
  /// Current recorder mode
  final RecorderMode mode;

  /// Creates a recording status indicator
  const RecordingStatusIndicator({
    super.key,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == RecorderMode.idle) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mode == RecorderMode.recording)
            const _PulsingDot(color: Colors.white),
          if (mode == RecorderMode.recording) const SizedBox(width: 4),
          Text(
            _getText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (mode) {
      case RecorderMode.recording:
        return Colors.red;
      case RecorderMode.playback:
        return Colors.green;
      default:
        return Colors.transparent;
    }
  }

  String _getText() {
    switch (mode) {
      case RecorderMode.recording:
        return 'RECORDING';
      case RecorderMode.playback:
        return 'PLAYING';
      default:
        return '';
    }
  }
}

/// Pulsing dot animation for recording indicator
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
