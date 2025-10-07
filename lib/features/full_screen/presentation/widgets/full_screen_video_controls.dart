import 'package:flutter/material.dart';

/// Full-screen video controls widget
class FullScreenVideoControls extends StatelessWidget {
  const FullScreenVideoControls({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isLooping,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.onMute,
    required this.onLoop,
    required this.onSeek,
  });

  final bool isPlaying;
  final bool isMuted;
  final bool isLooping;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onLoop;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        VideoProgressBar(
          currentPosition: currentPosition,
          totalDuration: totalDuration,
          onSeek: onSeek,
        ),

        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onLoop,
              icon: Icon(
                isLooping ? Icons.repeat_one : Icons.repeat,
                color: isLooping ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: colorScheme.onSurface,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: onMute,
              icon: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Video progress bar with scrubbing capability
class VideoProgressBar extends StatefulWidget {
  const VideoProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double _dragValue = 0.0;

  @override
  void didUpdateWidget(VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalDuration.inMilliseconds > 0) {
      _dragValue =
          widget.currentPosition.inMilliseconds /
          widget.totalDuration.inMilliseconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: colorScheme.onSurface,
            inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.3),
            thumbColor: colorScheme.onSurface,
            overlayColor: colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _dragValue,
            onChanged: (value) {
              setState(() => _dragValue = value);
            },
            onChangeEnd: (value) {
              final newPosition = Duration(
                milliseconds: (value * widget.totalDuration.inMilliseconds)
                    .round(),
              );
              widget.onSeek(newPosition);
            },
          ),
        ),

        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.currentPosition),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              ),
              Text(
                _formatDuration(widget.totalDuration),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
