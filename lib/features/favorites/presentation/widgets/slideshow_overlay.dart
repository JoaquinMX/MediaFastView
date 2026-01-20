import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/media_viewer_overlay.dart';
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
      showProgressBar: isVideo,
      showVideoLoop: isVideo,
      showPlaybackSpeed: isVideo,
    );

    if (isCompactLayout) {
      final primaryVisibility = playbackVisibility.copyWith(
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
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: MediaPlaybackControls(
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
              onPlayPause: onPlayPause,
              onNext: viewModel.nextItem,
              onPrevious: viewModel.previousItem,
              onToggleLoop: viewModel.toggleLoop,
              onToggleShuffle: viewModel.toggleShuffle,
              onToggleMute: viewModel.toggleMute,
              onToggleVideoLoop: viewModel.toggleVideoLoop,
              onDurationSelected: viewModel.setImageDisplayDuration,
              onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
              visibility: secondaryVisibility,
              style: MediaPlaybackControlStyle(
                iconTheme: const IconThemeData(color: Colors.white, size: 28),
                playPauseIconSize: 40,
                controlSpacing: 12,
                sectionSpacing: 20,
                durationSliderWidth: 180,
                progressBackgroundColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: _ControlsHint(delay: delay),
          ),
        ],
      );
    }

    return MediaViewerOverlay(
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
      playbackVisibility: playbackVisibility,
      showPlaybackForImages: true,
      footer: _ControlsHint(delay: delay),
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
