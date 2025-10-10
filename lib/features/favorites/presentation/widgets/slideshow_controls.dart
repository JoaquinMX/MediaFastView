import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
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

  static const Duration _defaultDuration = Duration(seconds: 5);

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
        _buildDurationSlider(context),
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

  Duration _currentImageDuration() {
    return switch (state) {
      SlideshowPlaying(:final imageDisplayDuration) => imageDisplayDuration,
      SlideshowPaused(:final imageDisplayDuration) => imageDisplayDuration,
      _ => _defaultDuration,
    };
  }

  Widget _buildDurationSlider(BuildContext context) {
    final minDuration = AppConfig.slideshowMinDuration;
    final maxDuration = AppConfig.slideshowMaxDuration;

    var minSeconds = minDuration.inSeconds;
    var maxSeconds = maxDuration.inSeconds;

    if (maxSeconds <= minSeconds) {
      maxSeconds = minSeconds + 1;
    }

    final currentDuration = _currentImageDuration();
    final currentSeconds = currentDuration.inSeconds;
    final clampedSeconds = currentSeconds < minSeconds
        ? minSeconds
        : (currentSeconds > maxSeconds ? maxSeconds : currentSeconds);

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Slide duration: ${clampedSeconds}s',
            style: const TextStyle(color: Colors.white),
          ),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.timer, color: Colors.white),
                tooltip: 'Adjust duration range',
                onPressed: () async {
                  final updatedRange = await _showDurationSettingsDialog(
                    context,
                    minSeconds,
                    maxSeconds,
                  );

                  if (updatedRange == null) {
                    return;
                  }

                  final minValue = updatedRange.minSeconds;
                  final maxValue = updatedRange.maxSeconds;

                  AppConfig.slideshowMinDuration =
                      Duration(seconds: minValue);
                  AppConfig.slideshowMaxDuration =
                      Duration(seconds: maxValue);

                  final targetSeconds = currentSeconds
                      .clamp(minValue, maxValue)
                      .toInt();
                  onDurationSelected(Duration(seconds: targetSeconds));
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blueAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    min: minSeconds.toDouble(),
                    max: maxSeconds.toDouble(),
                    divisions: maxSeconds - minSeconds,
                    value: clampedSeconds.toDouble(),
                    label: '${clampedSeconds}s',
                    onChanged: (value) {
                      final rounded = value.round();
                      final seconds = rounded < minSeconds
                          ? minSeconds
                          : (rounded > maxSeconds ? maxSeconds : rounded);
                      onDurationSelected(Duration(seconds: seconds));
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<({int minSeconds, int maxSeconds})?> _showDurationSettingsDialog(
    BuildContext context,
    int initialMin,
    int initialMax,
  ) async {
    final minController =
        TextEditingController(text: initialMin.toString());
    final maxController =
        TextEditingController(text: initialMax.toString());
    String? errorText;

    final result = await showDialog<({int minSeconds, int maxSeconds})>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set slide duration range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Minimum seconds',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Maximum seconds',
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final minValue = int.tryParse(minController.text);
                    final maxValue = int.tryParse(maxController.text);

                    if (minValue == null || maxValue == null) {
                      setState(() {
                        errorText = 'Please enter valid numbers.';
                      });
                      return;
                    }

                    if (minValue < 1) {
                      setState(() {
                        errorText =
                            'Minimum duration must be at least 1 second.';
                      });
                      return;
                    }

                    if (maxValue <= minValue) {
                      setState(() {
                        errorText =
                            'Maximum duration must be greater than minimum.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop((
                      minSeconds: minValue,
                      maxSeconds: maxValue,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    minController.dispose();
    maxController.dispose();
    return result;
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
