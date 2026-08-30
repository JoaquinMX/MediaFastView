import 'package:flutter/material.dart';

import 'media_progress_indicator.dart';
import 'playback_speed_control.dart';
import 'seekable_video_progress_bar.dart';

/// Configuration for VideoBottomControls widget
class VideoBottomControlsConfig {
  const VideoBottomControlsConfig({
    required this.showRow1,
    required this.showRow2,
    required this.showRow3,
    required this.showRow4,
    required this.showShuffleInRow4,
    required this.showVideoLoopInRow4,
    required this.isFullScreen,
    required this.currentIndex,
    required this.totalItems,
    required this.videoProgress,
    required this.onSeek,
    required this.totalDuration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.isLooping,
    required this.onToggleLoop,
    required this.isMuted,
    required this.onToggleMute,
    required this.isShuffleEnabled,
    required this.onToggleShuffle,
    required this.isVideoLooping,
    required this.onToggleVideoLoop,
    required this.playbackSpeed,
    required this.onPlaybackSpeedSelected,
    required this.playbackSpeedOptions,
  });

  final bool showRow1;
  final bool showRow2;
  final bool showRow3;
  final bool showRow4;
  final bool showShuffleInRow4;
  final bool showVideoLoopInRow4;
  final bool isFullScreen;
  final int currentIndex;
  final int totalItems;
  final double videoProgress;
  final ValueChanged<Duration> onSeek;
  final Duration totalDuration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool isLooping;
  final VoidCallback onToggleLoop;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final bool isShuffleEnabled;
  final VoidCallback onToggleShuffle;
  final bool isVideoLooping;
  final VoidCallback onToggleVideoLoop;
  final double playbackSpeed;
  final ValueChanged<double> onPlaybackSpeedSelected;
  final List<double> playbackSpeedOptions;
}

/// Bottom controls widget for video playback with configurable rows
class VideoBottomControls extends StatelessWidget {
  const VideoBottomControls({super.key, required this.config});

  final VideoBottomControlsConfig config;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // Row 1: Slideshow progress (if enabled)
    if (config.showRow1) {
      children.add(
        Positioned(
          bottom: 184,
          left: 16,
          right: 16,
          child: MediaProgressIndicator(
            currentIndex: config.currentIndex,
            totalItems: config.totalItems,
            progress: config.totalItems > 0
                ? (config.currentIndex + 1) / config.totalItems
                : 0,
            counterTextStyle: const TextStyle(color: Colors.white),
            progressColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    // Row 2: Video progress (if enabled)
    if (config.showRow2) {
      children.add(
        Positioned(
          bottom: 128,
          left: 16,
          right: 16,
          child: SeekableVideoProgressBar(
            progress: config.videoProgress,
            onSeek: config.onSeek,
            totalDuration: config.totalDuration,
          ),
        ),
      );
    }

    // Row 3: Primary controls (if enabled)
    if (config.showRow3) {
      children.add(
        Positioned(
          bottom: 72,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: config.onPrevious,
                tooltip: 'Previous',
              ),
              const SizedBox(width: 12),
              IconButton(
                iconSize: 40,
                icon: Icon(
                  config.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: config.onPlayPause,
                tooltip: config.isPlaying ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: config.onNext,
                tooltip: 'Next',
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(
                  config.isLooping ? Icons.repeat : Icons.repeat_one,
                  color: config.isLooping ? Colors.blue : Colors.white,
                ),
                onPressed: config.onToggleLoop,
                tooltip: config.isLooping ? 'Disable loop' : 'Enable loop',
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  config.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: config.onToggleMute,
                tooltip: config.isMuted ? 'Unmute' : 'Mute',
              ),
            ],
          ),
        ),
      );
    }

    // Row 4: Secondary controls (if enabled)
    if (config.showRow4) {
      children.add(
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.showShuffleInRow4)
                IconButton(
                  icon: Icon(
                    config.isShuffleEnabled ? Icons.shuffle : Icons.shuffle,
                    color: config.isShuffleEnabled ? Colors.blue : Colors.white,
                  ),
                  onPressed: config.onToggleShuffle,
                  tooltip: config.isShuffleEnabled
                      ? 'Disable shuffle'
                      : 'Enable shuffle',
                ),
              if (config.showShuffleInRow4) const SizedBox(width: 12),
              _buildPlaybackSpeedButton(),
              if (config.showVideoLoopInRow4) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    config.isVideoLooping ? Icons.repeat_one : Icons.repeat_one,
                    color: config.isVideoLooping ? Colors.blue : Colors.white,
                  ),
                  onPressed: config.onToggleVideoLoop,
                  tooltip: config.isVideoLooping
                      ? 'Disable video loop'
                      : 'Loop current video',
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(children: children);
  }

  Widget _buildPlaybackSpeedButton() {
    return PlaybackSpeedControl(
      playbackSpeed: config.playbackSpeed,
      playbackSpeedOptions: config.playbackSpeedOptions,
      onPlaybackSpeedSelected: config.onPlaybackSpeedSelected,
    );
  }
}
