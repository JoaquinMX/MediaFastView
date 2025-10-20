import 'package:flutter/material.dart';

import '../../../../shared/widgets/media_playback_controls.dart';

class FullScreenVideoProgressSlider extends StatefulWidget {
  const FullScreenVideoProgressSlider({
    super.key,
    required this.progress,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    required this.style,
  });

  final double progress;
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;
  final MediaPlaybackControlStyle style;

  @override
  State<FullScreenVideoProgressSlider> createState() =>
      _FullScreenVideoProgressSliderState();
}

class _FullScreenVideoProgressSliderState
    extends State<FullScreenVideoProgressSlider> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(FullScreenVideoProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _syncFromWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDuration = widget.totalDuration.inMilliseconds > 0;
    final sliderValue = hasDuration ? _dragValue.clamp(0.0, 1.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.style.sliderActiveTrackColor,
            inactiveTrackColor: widget.style.sliderInactiveTrackColor,
            thumbColor: widget.style.sliderThumbColor,
            overlayColor: widget.style.sliderOverlayColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackHeight: 4,
          ),
          child: Slider(
            value: sliderValue,
            min: 0,
            max: 1,
            onChangeStart: hasDuration
                ? (_) => setState(() => _isDragging = true)
                : null,
            onChanged: hasDuration
                ? (value) => setState(() => _dragValue = value)
                : null,
            onChangeEnd: hasDuration
                ? (value) {
                    setState(() {
                      _isDragging = false;
                      _dragValue = value;
                    });
                    final targetMilliseconds =
                        (value * widget.totalDuration.inMilliseconds).round();
                    final safeMilliseconds = targetMilliseconds.clamp(
                      0,
                      widget.totalDuration.inMilliseconds,
                    );
                    widget.onSeek(Duration(milliseconds: safeMilliseconds));
                  }
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(widget.currentPosition),
              style: widget.style.durationLabelTextStyle,
            ),
            Text(
              _formatDuration(widget.totalDuration),
              style: widget.style.durationLabelTextStyle,
            ),
          ],
        ),
      ],
    );
  }

  void _syncFromWidget() {
    final total = widget.totalDuration.inMilliseconds;
    if (total <= 0) {
      _dragValue = widget.progress.clamp(0.0, 1.0);
      return;
    }

    final position = widget.currentPosition.inMilliseconds.clamp(0, total);
    _dragValue = total == 0 ? 0.0 : position / total;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
