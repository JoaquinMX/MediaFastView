import 'package:flutter/material.dart';

/// Seekable video progress bar widget that supports interactive scrubbing
/// with throttling to prevent excessive seek operations.
class SeekableVideoProgressBar extends StatefulWidget {
  const SeekableVideoProgressBar({
    super.key,
    required this.progress,
    required this.onSeek,
    required this.totalDuration,
  });

  final double progress;
  final ValueChanged<Duration> onSeek;
  final Duration totalDuration;

  @override
  State<SeekableVideoProgressBar> createState() =>
      _SeekableVideoProgressBarState();
}

class _SeekableVideoProgressBarState extends State<SeekableVideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  DateTime? _lastSeekTime;

  @override
  void didUpdateWidget(covariant SeekableVideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _dragValue = widget.progress;
    }
  }

  void _throttledSeek(double value) {
    final now = DateTime.now();
    if (_lastSeekTime == null ||
        now.difference(_lastSeekTime!) > const Duration(milliseconds: 100)) {
      _lastSeekTime = now;
      final posMs = value * widget.totalDuration.inMilliseconds;
      final seekPosition = Duration(milliseconds: posMs.round());
      widget.onSeek(seekPosition);
    }
    setState(() {
      _dragValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        value: _isDragging ? _dragValue : widget.progress,
        onChangeStart: (value) {
          setState(() {
            _isDragging = true;
            _dragValue = value;
          });
        },
        onChanged: _throttledSeek,
        onChangeEnd: (value) {
          setState(() {
            _isDragging = false;
            _lastSeekTime = null;
          });
          final posMs = value * widget.totalDuration.inMilliseconds;
          final seekPosition = Duration(milliseconds: posMs.round());
          widget.onSeek(seekPosition);
        },
      ),
    );
  }
}
