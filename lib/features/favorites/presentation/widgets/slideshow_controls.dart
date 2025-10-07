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
  });

  final SlideshowState state;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Row(
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

        const SizedBox(width: 32),

        // Loop toggle
        _buildLoopButton(),

        const SizedBox(width: 16),

        // Mute toggle
        _buildMuteButton(),

        const SizedBox(width: 32),

        // Progress bar (for video controls)
        if (_isVideoState()) _buildProgressBar(),
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
