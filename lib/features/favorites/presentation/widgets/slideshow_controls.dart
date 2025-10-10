import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_fast_view/core/config/app_config.dart';

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
    required this.onDurationSelected,
  });

  final SlideshowState state;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleShuffle;
  final ValueChanged<Duration> onDurationSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: onPrevious,
          tooltip: 'Previous',
          iconSize: 32,
        ),
        const SizedBox(width: 16),
        _buildPlayPauseButton(),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: onNext,
          tooltip: 'Next',
          iconSize: 32,
        ),
        const SizedBox(width: 32),
        _buildLoopButton(),
        const SizedBox(width: 16),
        _buildShuffleButton(),
        const SizedBox(width: 16),
        _buildMuteButton(),
        const SizedBox(width: 32),
        Flexible(
          flex: 3,
          child: _buildDurationSlider(context),
        ),
        const SizedBox(width: 32),
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

  Widget _buildShuffleButton() {
    final isShuffled = switch (state) {
      SlideshowPlaying(:final isShuffleEnabled) => isShuffleEnabled,
      SlideshowPaused(:final isShuffleEnabled) => isShuffleEnabled,
      _ => false,
    };

    return IconButton(
      icon: Icon(
        Icons.shuffle,
        color: isShuffled ? Colors.blue : Colors.white,
      ),
      onPressed: onToggleShuffle,
      tooltip: isShuffled ? 'Disable shuffle' : 'Enable shuffle',
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

  Widget _buildDurationSlider(BuildContext context) {
    const fallbackDuration = Duration(seconds: 5);

    final currentDuration = switch (state) {
      SlideshowPlaying(:final imageDisplayDuration) => imageDisplayDuration,
      SlideshowPaused(:final imageDisplayDuration) => imageDisplayDuration,
      _ => fallbackDuration,
    };

    final rawMinSeconds = AppConfig.slideshowMinDuration.inSeconds;
    final rawMaxSeconds = AppConfig.slideshowMaxDuration.inSeconds;

    final normalizedMin = rawMinSeconds <= 0 ? 1 : rawMinSeconds;
    final normalizedMax = rawMaxSeconds <= 0 ? 1 : rawMaxSeconds;

    final effectiveMin = math.min(normalizedMin, normalizedMax).toDouble();
    final effectiveMax = math.max(normalizedMin, normalizedMax).toDouble();
    final hasRange = effectiveMax > effectiveMin;

    final clampedValue = currentDuration.inSeconds
        .clamp(effectiveMin, effectiveMax)
        .toDouble();

    final divisions = hasRange ? (effectiveMax - effectiveMin).round() : null;

    final label = '${clampedValue.round()}s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              hasRange ? 'Slide duration: $label' : 'Slide duration locked: $label',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.1),
            valueIndicatorColor: Colors.white,
            valueIndicatorTextStyle: const TextStyle(color: Colors.black),
          ),
          child: Slider(
            value: clampedValue,
            min: effectiveMin,
            max: effectiveMax,
            divisions: divisions,
            label: label,
            onChanged: hasRange
                ? (value) {
                    final newSeconds = value.round();
                    final clampedSeconds = newSeconds
                        .clamp(effectiveMin.round(), effectiveMax.round());
                    final durationSeconds = clampedSeconds.toInt();
                    if (durationSeconds != currentDuration.inSeconds) {
                      onDurationSelected(
                        Duration(seconds: durationSeconds),
                      );
                    }
                  }
                : null,
          ),
        ),
        if (hasRange)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${effectiveMin.round()}s',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${effectiveMax.round()}s',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
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
