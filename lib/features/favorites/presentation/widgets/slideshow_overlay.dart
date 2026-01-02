import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/shared/widgets/media_playback_controls.dart';
import 'package:media_fast_view/shared/widgets/media_progress_indicator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/tag_overlay.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../../shared/utils/tag_mutation_service.dart';
import '../widgets/favorite_toggle_button.dart';
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
    final topDisplay = _SlideshowOverlayDisplay(
      alignment: Alignment.topCenter,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
      ),
      padding: const EdgeInsets.all(16),
      safeAreaTop: true,
      sections: [
        _HeaderSection(
          media: viewModel.currentMedia,
          onClose: onClose,
        ),
        if (viewModel.currentMedia != null)
          _TagSection(
            media: viewModel.currentMedia!,
            viewModel: viewModel,
          ),
      ],
      sectionSpacing: 12,
    );

    final bottomDisplay = _SlideshowOverlayDisplay(
      alignment: Alignment.bottomCenter,
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
      ),
      padding: const EdgeInsets.all(16),
      safeAreaBottom: true,
      sections: [
        _ProgressSection(viewModel: viewModel),
        _PlaybackSection(
          state: state,
          viewModel: viewModel,
          onPlayPause: onPlayPause,
        ),
      ],
      footer: _ControlsHint(delay: controlsHideDelay),
      footerSpacing: 8,
    );

    return Stack(
      children: [
        topDisplay,
        bottomDisplay,
      ],
    );
  }
}

class _SlideshowOverlayDisplay extends StatelessWidget {
  const _SlideshowOverlayDisplay({
    required this.gradient,
    required this.sections,
    required this.padding,
    this.footer,
    this.footerSpacing = 16,
    this.alignment = Alignment.bottomCenter,
    this.safeAreaTop = false,
    this.safeAreaBottom = false,
    this.sectionSpacing = 16,
  });

  final Alignment alignment;
  final LinearGradient gradient;
  final List<Widget> sections;
  final Widget? footer;
  final double footerSpacing;
  final EdgeInsets padding;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          top: safeAreaTop,
          bottom: safeAreaBottom,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildSectionsWithSpacing(sections),
                if (footer != null) ...[
                  if (sections.isNotEmpty && footerSpacing > 0)
                    SizedBox(height: footerSpacing),
                  footer!,
                ],
              ],
            ),
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
        builtSections.add(SizedBox(height: sectionSpacing));
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

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.media, required this.onClose});

  final MediaEntity? media;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Close slideshow',
          onPressed: onClose,
        ),
        const Spacer(),
        if (media != null) FavoriteToggleButton(media: media!),
      ],
    );
  }
}

class _TagSection extends ConsumerWidget {
  const _TagSection({required this.media, required this.viewModel});

  final MediaEntity media;
  final SlideshowViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_slideshowTagsProvider);
    return tagsAsync.when(
      data: (tags) => TagOverlay(
        tags: tags,
        selectedTagIds: media.tagIds.toSet(),
        onTagTapped: (tag) => _handleTagTap(context, tag),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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

  void _showFeedback(BuildContext context, String message,
      {required bool isError}) {
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
      playbackSpeed: viewModel.playbackSpeed,
      playbackSpeedOptions: const [1.0, 2.0, 2.5, 3.0, 4.0],
      onPlaybackSpeedSelected: viewModel.setPlaybackSpeed,
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
        showPlaybackSpeed: viewModel.currentMedia?.type == MediaType.video,
      ),
      style: MediaPlaybackControlStyle(
        progressBackgroundColor: Colors.white.withValues(alpha: 0.3),
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

