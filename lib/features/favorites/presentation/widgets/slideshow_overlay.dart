import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/shared/widgets/media_progress_indicator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/base_media_viewer_overlay.dart';
import '../../../../shared/widgets/media_viewer_overlay.dart';
import '../../../../shared/widgets/video_bottom_controls.dart';
import '../../../../shared/widgets/media_playback_controls.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../../shared/utils/tag_mutation_service.dart';
import '../widgets/favorite_toggle_button.dart';
import '../view_models/slideshow_view_model.dart';

final _slideshowTagsProvider = FutureProvider.autoDispose<List<TagEntity>>((
  ref,
) {
  final lookup = ref.watch(tagLookupProvider);
  return lookup.getAllTags();
});

class SlideshowOverlay extends ConsumerWidget {
  const SlideshowOverlay({
    super.key,
    required this.state,
    required this.viewModel,
    required this.onClose,
    required this.onPlayPause,
  });

  final SlideshowState state;
  final SlideshowViewModel viewModel;
  final VoidCallback onClose;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlsHideDelay = ref.watch(slideshowControlsHideDelayProvider);
    final tagsAsync = ref.watch(_slideshowTagsProvider);

    return tagsAsync.when(
      data: (tags) => _buildOverlay(context, tags, controlsHideDelay),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    List<TagEntity> tags,
    Duration delay,
  ) {
    final isCompactLayout = MediaQuery.sizeOf(context).width < 600;
    final isVideo = viewModel.currentMedia?.type == MediaType.video;

    final isPlaying = switch (state) {
      SlideshowPlaying(:final isPlaying) => isPlaying,
      SlideshowPaused() => false,
      _ => false,
    };

    final isLooping = switch (state) {
      SlideshowPlaying(:final isLooping) => isLooping,
      SlideshowPaused(:final isLooping) => isLooping,
      _ => false,
    };

    final isShuffleEnabled = switch (state) {
      SlideshowPlaying(:final isShuffleEnabled) => isShuffleEnabled,
      SlideshowPaused(:final isShuffleEnabled) => isShuffleEnabled,
      _ => false,
    };

    final isMuted = viewModel.isMuted;
    final isVideoLooping = viewModel.isVideoLooping;
    final playbackSpeed = viewModel.playbackSpeed;
    final progress = switch (state) {
      SlideshowPlaying(:final progress) => progress,
      SlideshowPaused(:final progress) => progress,
      _ => 0.0,
    };

    final imageDisplayDuration = switch (state) {
      SlideshowPlaying(:final imageDisplayDuration) => imageDisplayDuration,
      SlideshowPaused(:final imageDisplayDuration) => imageDisplayDuration,
      _ => const Duration(seconds: 5),
    };

    final playbackVisibility = MediaPlaybackControlVisibility(
      showProgressBar: false, // VideoBottomControls handle progress for videos
      showVideoLoop: isVideo,
      showPlaybackSpeed: isVideo,
    );

    final playbackSpeedOptions = const [1.0, 2.0, 2.5, 3.0, 4.0];

    Widget _buildPlaybackSpeedButton() {
      final speeds = playbackSpeedOptions.toSet().toList()..sort();
      final currentSpeed = playbackSpeed ?? speeds.first;
      final enabled = viewModel.setPlaybackSpeed != null;

      return PopupMenuButton<double>(
        tooltip: 'Playback speed',
        enabled: enabled,
        initialValue: currentSpeed,
        onSelected: enabled ? viewModel.setPlaybackSpeed : null,
        itemBuilder: (context) {
          return speeds
              .map(
                (speed) => PopupMenuItem<double>(
                  value: speed,
                  child: Row(
                    children: [
                      if (speed == currentSpeed)
                        Icon(Icons.check, color: Colors.blue, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text('${speed}x'),
                    ],
                  ),
                ),
              )
              .toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                '${currentSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isCompactLayout) {
      final primaryVisibility = playbackVisibility.copyWith(
        showPrevious: false,
        showPlayPause: false,
        showNext: false,
        showLoop: false,
        showMute: false,
        showShuffle: false,
        showDurationSlider: false,
        showProgressBar: false,
        showVideoLoop: false,
        showPlaybackSpeed: false,
      );

      final secondaryVisibility = playbackVisibility.copyWith(
        showPrevious: false,
        showPlayPause: false,
        showNext: false,
        showLoop: false,
        showMute: false,
        showProgressBar: false,
      );

      return Stack(
        children: [
          MediaViewerOverlay(
            media: viewModel.currentMedia,
            tags: tags,
            selectedTagIds: viewModel.currentMedia?.tagIds.toSet() ?? const {},
            onTagTapped: (tag) => _handleTagTap(context, tag),
            leadingAction: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close slideshow',
              onPressed: onClose,
            ),
            trailingActions: [
              if (viewModel.currentMedia != null)
                FavoriteToggleButton(media: viewModel.currentMedia!),
            ],
            progress: MediaProgressData(
              currentIndex: viewModel.currentIndex,
              totalItems: viewModel.totalItems,
              progress: viewModel.totalItems > 0
                  ? (viewModel.currentIndex + 1) / viewModel.totalItems
                  : 0,
              showProgressBar: false,
            ),
            playback: MediaPlaybackData(
              isPlaying: isPlaying,
              isLooping: isLooping,
              isShuffleEnabled: isShuffleEnabled,
              isMuted: isMuted,
              isVideoLooping: isVideoLooping,
              playbackSpeed: playbackSpeed,
              playbackSpeedOptions: const [1.0, 2.0, 2.5, 3.0, 4.0],
              progress: progress,
              minDuration: AppConfig.slideshowMinDuration,
              maxDuration: AppConfig.slideshowMaxDuration,
              currentItemDuration: imageDisplayDuration,
            ),
            onPlayPause: onPlayPause,
            onNext: viewModel.nextItem,
            onPrevious: viewModel.previousItem,
            onToggleLoop: viewModel.toggleLoop,
            onToggleShuffle: viewModel.toggleShuffle,
            onToggleMute: viewModel.toggleMute,
            onToggleVideoLoop: viewModel.toggleVideoLoop,
            onDurationSelected: viewModel.setImageDisplayDuration,
            onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
            playbackVisibility: primaryVisibility,
            showPlaybackForImages: true,
            playbackStyle: MediaPlaybackControlStyle(
              progressBackgroundColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          // Row 1: Slideshow progress (all media)
          Positioned(
            bottom: 184,
            left: 16,
            right: 16,
            child: MediaProgressIndicator(
              currentIndex: viewModel.currentIndex,
              totalItems: viewModel.totalItems,
              progress: viewModel.totalItems > 0
                  ? (viewModel.currentIndex + 1) / viewModel.totalItems
                  : 0,
              counterTextStyle: const TextStyle(color: Colors.white),
              progressColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          // Row 2: Conditional (video progress or empty)
          Positioned(
            bottom: 128,
            left: 16,
            right: 16,
            child: isVideo
                ? _SeekableVideoProgressBar(
                    progress:
                        state is SlideshowPlaying &&
                            (state as SlideshowPlaying)
                                    .totalDuration
                                    .inMilliseconds >
                                0
                        ? (state as SlideshowPlaying)
                                  .currentPosition
                                  .inMilliseconds /
                              (state as SlideshowPlaying)
                                  .totalDuration
                                  .inMilliseconds
                        : 0.0,
                    onSeek: viewModel.seekVideo,
                    totalDuration: state is SlideshowPlaying
                        ? (state as SlideshowPlaying).totalDuration
                        : Duration.zero,
                  )
                : SizedBox(height: 48), // Empty space, same height
          ),
          // Row 3: Primary controls (all media)
          Positioned(
            bottom: 72,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: viewModel.previousItem,
                  tooltip: 'Previous',
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 40,
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onPlayPause,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: viewModel.nextItem,
                  tooltip: 'Next',
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    isLooping ? Icons.repeat : Icons.repeat_one,
                    color: isLooping ? Colors.blue : Colors.white,
                  ),
                  onPressed: viewModel.toggleLoop,
                  tooltip: isLooping ? 'Disable loop' : 'Enable loop',
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: viewModel.toggleMute,
                  tooltip: isMuted ? 'Unmute' : 'Mute',
                ),
              ],
            ),
          ),
          // Row 4: Secondary controls (shuffle always, conditional elements)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isShuffleEnabled ? Icons.shuffle : Icons.shuffle,
                    color: isShuffleEnabled ? Colors.blue : Colors.white,
                  ),
                  onPressed: viewModel.toggleShuffle,
                  tooltip: isShuffleEnabled
                      ? 'Disable shuffle'
                      : 'Enable shuffle',
                ),
                const SizedBox(width: 16),
                if (isVideo) ...[
                  _buildPlaybackSpeedButton(),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      isVideoLooping ? Icons.repeat_one : Icons.repeat_one,
                      color: isVideoLooping ? Colors.blue : Colors.white,
                    ),
                    onPressed: viewModel.toggleVideoLoop,
                    tooltip: isVideoLooping
                        ? 'Disable video loop'
                        : 'Loop current video',
                  ),
                ] else
                  Expanded(
                    child: _DurationSlider(
                      currentDuration: imageDisplayDuration,
                      onDurationChanged: viewModel.setImageDisplayDuration,
                      minDuration: AppConfig.slideshowMinDuration,
                      maxDuration: AppConfig.slideshowMaxDuration,
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            bottom: 240,
            left: 16,
            right: 16,
            child: _ControlsHint(delay: delay),
          ),
        ],
      );
    }

    return BaseMediaViewerOverlay.slideshow(
      media: viewModel.currentMedia,
      tags: tags,
      selectedTagIds: viewModel.currentMedia?.tagIds.toSet() ?? const {},
      onTagTapped: (tag) => _handleTagTap(context, tag),
      closeButton: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        tooltip: 'Close slideshow',
        onPressed: onClose,
      ),
      favoriteButton: viewModel.currentMedia != null
          ? FavoriteToggleButton(media: viewModel.currentMedia!)
          : null,
      progress: MediaProgressData(
        currentIndex: viewModel.currentIndex,
        totalItems: viewModel.totalItems,
        progress: viewModel.totalItems > 0
            ? (viewModel.currentIndex + 1) / viewModel.totalItems
            : 0,
      ),
      playback: MediaPlaybackData(
        isPlaying: isPlaying,
        isLooping: isLooping,
        isShuffleEnabled: isShuffleEnabled,
        isMuted: isMuted,
        isVideoLooping: isVideoLooping,
        playbackSpeed: playbackSpeed,
        playbackSpeedOptions: const [1.0, 2.0, 2.5, 3.0, 4.0],
        progress: progress,
        minDuration: AppConfig.slideshowMinDuration,
        maxDuration: AppConfig.slideshowMaxDuration,
        currentItemDuration: imageDisplayDuration,
      ),
      onPlayPause: onPlayPause,
      onNext: viewModel.nextItem,
      onPrevious: viewModel.previousItem,
      onToggleLoop: viewModel.toggleLoop,
      onToggleShuffle: viewModel.toggleShuffle,
      onToggleMute: viewModel.toggleMute,
      onToggleVideoLoop: viewModel.toggleVideoLoop,
      onDurationSelected: viewModel.setImageDisplayDuration,
      onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
      onSeek: viewModel.seekVideo,
      playbackVisibility: playbackVisibility,
      showPlaybackForImages:
          true, // Restore overlay controls for images in non-compact view
      footer: _ControlsHint(delay: delay),
      showBottomControls:
          isVideo, // Show 3-row layout for videos in non-compact view
      bottomControlsConfig: isVideo
          ? VideoBottomControlsConfig(
              showRow1: false, // Hide counter (shown in overlay)
              showRow2: true, // Show progress bar
              showRow3: false, // Hide primary controls (shown in overlay)
              showRow4: false, // Hide secondary row
              showShuffleInRow4: true,
              showVideoLoopInRow4: true,
              isFullScreen: false,
              currentIndex: viewModel.currentIndex,
              totalItems: viewModel.totalItems,
              videoProgress: progress,
              onSeek: viewModel.seekVideo,
              totalDuration: state is SlideshowPlaying
                  ? (state as SlideshowPlaying).totalDuration
                  : Duration.zero,
              isPlaying: isPlaying,
              onPlayPause: onPlayPause,
              onNext: viewModel.nextItem,
              onPrevious: viewModel.previousItem,
              isLooping: isLooping,
              onToggleLoop: viewModel.toggleLoop,
              isMuted: isMuted,
              onToggleMute: viewModel.toggleMute,
              isShuffleEnabled: isShuffleEnabled,
              onToggleShuffle: viewModel.toggleShuffle,
              isVideoLooping: isVideoLooping,
              onToggleVideoLoop: viewModel.toggleVideoLoop,
              playbackSpeed: playbackSpeed,
              onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
              playbackSpeedOptions: const [1.0, 2.0, 2.5, 3.0, 4.0],
            )
          : null,
    );
  }

  Future<void> _handleTagTap(BuildContext context, TagEntity tag) async {
    try {
      final result = await viewModel.toggleTag(tag);
      final message = switch (result.outcome) {
        TagMutationOutcome.added => 'Added "${tag.name}"',
        TagMutationOutcome.removed => 'Removed "${tag.name}"',
        TagMutationOutcome.unchanged => 'No changes to "${tag.name}"',
      };
      _showFeedback(context, message, isError: false);
    } catch (error) {
      _showFeedback(
        context,
        'Failed to update "${tag.name}": $error',
        isError: true,
      );
    }
  }

  void _showFeedback(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final colorScheme = Theme.of(context).colorScheme;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ControlsHint extends StatelessWidget {
  const _ControlsHint({required this.delay});

  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final seconds = delay.inSeconds;
    return Text(
      'Controls hide after $seconds second${seconds == 1 ? '' : 's'} of inactivity',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.white70),
    );
  }
}

class _SeekableVideoProgressBar extends StatefulWidget {
  const _SeekableVideoProgressBar({
    required this.progress,
    required this.onSeek,
    required this.totalDuration,
  });

  final double progress;
  final ValueChanged<Duration> onSeek;
  final Duration totalDuration;

  @override
  State<_SeekableVideoProgressBar> createState() =>
      _SeekableVideoProgressBarState();
}

class _DurationSlider extends StatefulWidget {
  const _DurationSlider({
    required this.currentDuration,
    required this.onDurationChanged,
    required this.minDuration,
    required this.maxDuration,
  });

  final Duration currentDuration;
  final ValueChanged<Duration> onDurationChanged;
  final Duration minDuration;
  final Duration maxDuration;

  @override
  State<_DurationSlider> createState() => _DurationSliderState();
}

class _DurationSliderState extends State<_DurationSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentDuration.inSeconds.toDouble();
  }

  @override
  void didUpdateWidget(covariant _DurationSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDuration != widget.currentDuration) {
      _value = widget.currentDuration.inSeconds.toDouble();
    }
  }

  void _onChanged(double value) {
    setState(() {
      _value = value;
    });
    widget.onDurationChanged(Duration(seconds: value.round()));
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
        showValueIndicator: ShowValueIndicator.always,
      ),
      child: Slider(
        value: _value,
        min: widget.minDuration.inSeconds.toDouble(),
        max: widget.maxDuration.inSeconds.toDouble(),
        label: '${_value.round()}s',
        onChanged: _onChanged,
      ),
    );
  }
}

class _SeekableVideoProgressBarState extends State<_SeekableVideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  DateTime? _lastSeekTime;

  @override
  void didUpdateWidget(covariant _SeekableVideoProgressBar oldWidget) {
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
