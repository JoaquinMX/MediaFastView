import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/shared/widgets/media_playback_controls.dart';
import 'package:media_fast_view/shared/widgets/media_progress_indicator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/providers/slideshow_controls_hide_delay_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/tag_overlay.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../view_models/slideshow_view_model.dart';

final _slideshowTagsProvider = FutureProvider.autoDispose<List<TagEntity>>((ref) {
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
    final sections = <Widget>[
      _ProgressSection(viewModel: viewModel),
      if (viewModel.currentMedia != null)
        _TagSection(media: viewModel.currentMedia!),
      _PlaybackSection(state: state, viewModel: viewModel, onPlayPause: onPlayPause),
      _CloseSection(onClose: onClose),
    ];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._buildSectionsWithSpacing(sections),
              const SizedBox(height: 8),
              _ControlsHint(delay: controlsHideDelay),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSectionsWithSpacing(List<Widget> sections) {
    final builtSections = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      builtSections.add(sections[i]);
      if (i != sections.length - 1) {
        builtSections.add(const SizedBox(height: 16));
      }
    }
    return builtSections;
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.viewModel});

  final SlideshowViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MediaProgressIndicator(
      currentIndex: viewModel.currentIndex,
      totalItems: viewModel.totalItems,
      progress: viewModel.totalItems > 0
          ? (viewModel.currentIndex + 1) / viewModel.totalItems
          : 0,
      counterTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      progressColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.3),
    );
  }
}

class _TagSection extends ConsumerWidget {
  const _TagSection({required this.media});

  final MediaEntity media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_slideshowTagsProvider);
    return tagsAsync.when(
      data: (tags) => TagOverlay(
        tags: tags,
        selectedTagIds: media.tagIds.toSet(),
        onTagTapped: null,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.state,
    required this.viewModel,
    required this.onPlayPause,
  });

  final SlideshowState state;
  final SlideshowViewModel viewModel;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return MediaPlaybackControls(
      isPlaying: viewModel.isPlaying,
      isLooping: viewModel.isLooping,
      isShuffleEnabled: switch (state) {
        SlideshowPlaying(:final isShuffleEnabled) => isShuffleEnabled,
        SlideshowPaused(:final isShuffleEnabled) => isShuffleEnabled,
        _ => false,
      },
      isMuted: viewModel.isMuted,
      isVideoLooping: viewModel.isVideoLooping,
      progress: switch (state) {
        SlideshowPlaying(:final progress) => progress,
        SlideshowPaused(:final progress) => progress,
        _ => 0.0,
      },
      minDuration: AppConfig.slideshowMinDuration,
      maxDuration: AppConfig.slideshowMaxDuration,
      currentItemDuration: switch (state) {
        SlideshowPlaying(:final imageDisplayDuration) => imageDisplayDuration,
        SlideshowPaused(:final imageDisplayDuration) => imageDisplayDuration,
        _ => const Duration(seconds: 5),
      },
      onPlayPause: onPlayPause,
      onNext: viewModel.nextItem,
      onPrevious: viewModel.previousItem,
      onToggleLoop: viewModel.toggleLoop,
      onToggleShuffle: viewModel.toggleShuffle,
      onToggleMute: viewModel.toggleMute,
      onToggleVideoLoop: viewModel.toggleVideoLoop,
      onDurationSelected: viewModel.setImageDisplayDuration,
      visibility: MediaPlaybackControlVisibility(
        showProgressBar: viewModel.currentMedia?.type == MediaType.video,
        showVideoLoop: viewModel.currentMedia?.type == MediaType.video,
      ),
      style: MediaPlaybackControlStyle(
        progressBackgroundColor: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }
}

class _CloseSection extends StatelessWidget {
  const _CloseSection({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onClose,
        tooltip: 'Close slideshow',
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
    );
  }
}

