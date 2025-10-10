import 'package:flutter/material.dart';

import '../view_models/slideshow_view_model.dart';

/// Controls widget for the slideshow with play/pause, navigation, and settings.
class SlideshowControls extends StatelessWidget {
  const SlideshowControls({
    super.key,
    required this.state,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleLoop,
    required this.onToggleMute,
    required this.onToggleShuffle,
    required this.onDurationChanged,
  });

  final SlideshowState state;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final ValueChanged<double> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = switch (state) {
      SlideshowPlaying(:final displayDuration) =>
          displayDuration.inMilliseconds / 1000,
      SlideshowPaused(:final displayDuration) =>
          displayDuration.inMilliseconds / 1000,
      _ => 5.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: onPrevious,
              tooltip: 'Previous',
              iconSize: 32,
            ),

            const SizedBox(width: 16),

            // Play/Pause button
            _buildPlayPauseButton(),

            const SizedBox(width: 16),

            // Next button
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: onNext,
              tooltip: 'Next',
              iconSize: 32,
            ),

            const SizedBox(width: 24),

            // Shuffle toggle
            _buildShuffleButton(),

            const SizedBox(width: 16),

            // Loop toggle
            _buildLoopButton(),

            const SizedBox(width: 16),

            // Mute toggle
            _buildMuteButton(),

            const SizedBox(width: 24),

            // Progress bar (for video controls)
            if (_isVideoState()) _buildProgressBar(),
          ],
        ),

        const SizedBox(height: 12),

        _buildDurationControl(durationSeconds),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    final isPlaying =
        state is SlideshowPlaying && (state as SlideshowPlaying).isPlaying;

    return IconButton(
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
      ),
      onPressed: onPlayPause,
      tooltip: isPlaying ? 'Pause' : 'Play',
      iconSize: 48,
    );
  }

  Widget _buildLoopButton() {
    final isLooping = switch (state) {
      SlideshowPlaying(:final isLooping) => isLooping,
      SlideshowPaused(:final isLooping) => isLooping,
      _ => false,
    };

    return IconButton(
      icon: Icon(
        isLooping ? Icons.repeat : Icons.repeat_one,
        color: isLooping ? Colors.blue : Colors.white,
      ),
      onPressed: onToggleLoop,
      tooltip: isLooping ? 'Disable loop' : 'Enable loop',
    );
  }

  Widget _buildMuteButton() {
    final isMuted = switch (state) {
      SlideshowPlaying(:final isMuted) => isMuted,
      SlideshowPaused(:final isMuted) => isMuted,
      _ => false,
    };

    return IconButton(
      icon: Icon(
        isMuted ? Icons.volume_off : Icons.volume_up,
        color: Colors.white,
      ),
      onPressed: onToggleMute,
      tooltip: isMuted ? 'Unmute' : 'Mute',
    );
  }

  Widget _buildShuffleButton() {
    final isShuffleEnabled = switch (state) {
      SlideshowPlaying(:final isShuffleEnabled) => isShuffleEnabled,
      SlideshowPaused(:final isShuffleEnabled) => isShuffleEnabled,
      _ => false,
    };

    return IconButton(
      icon: Icon(
        Icons.shuffle,
        color: isShuffleEnabled ? Colors.blue : Colors.white,
      ),
      onPressed: onToggleShuffle,
      tooltip: isShuffleEnabled ? 'Disable shuffle' : 'Enable shuffle',
    );
  }

  Widget _buildDurationControl(double durationSeconds) {
    const double minSeconds = 2;
    const double maxSeconds = 15;
    final bool canAdjust = state is SlideshowPlaying || state is SlideshowPaused;
    final double clampedValue =
        durationSeconds.clamp(minSeconds, maxSeconds).toDouble();
    final String label = clampedValue.toStringAsFixed(0);

    return Row(
      children: [
        const Icon(Icons.timer, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: clampedValue,
            min: minSeconds,
            max: maxSeconds,
            divisions: (maxSeconds - minSeconds).round(),
            label: '$label s',
            onChanged: canAdjust ? onDurationChanged : null,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$label s',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = switch (state) {
      SlideshowPlaying(:final progress) => progress,
      SlideshowPaused(:final progress) => progress,
      _ => 0.0,
    };

    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  bool _isVideoState() {
    // This would check if the current media is a video
    // For now, return false as we don't have video detection
    return false;
  }
}
