import 'package:flutter/material.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/tagging/domain/entities/tag_entity.dart';
import 'media_viewer_overlay.dart';
import 'media_playback_controls.dart';
import 'video_bottom_controls.dart';

/// Base media viewer overlay that provides common functionality
/// for both full-screen and slideshow contexts with factory methods
/// for specific configurations.
class BaseMediaViewerOverlay extends StatelessWidget {
  const BaseMediaViewerOverlay._({
    super.key,
    required this.media,
    required this.tags,
    required this.selectedTagIds,
    required this.onTagTapped,
    required this.leadingAction,
    required this.trailingActions,
    required this.progress,
    required this.playback,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleLoop,
    required this.onToggleShuffle,
    required this.onToggleMute,
    required this.onToggleVideoLoop,
    required this.onDurationSelected,
    required this.onPlaybackSpeedSelected,
    required this.onSeek,
    required this.playbackVisibility,
    required this.showPlaybackForImages,
    required this.footer,
    required this.showBottomControls,
    required this.bottomControlsConfig,
  });

  final MediaEntity? media;
  final List<TagEntity> tags;
  final Set<String> selectedTagIds;
  final ValueChanged<TagEntity>? onTagTapped;
  final Widget? leadingAction;
  final List<Widget> trailingActions;
  final MediaProgressData progress;
  final MediaPlaybackData playback;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleLoop;
  final VoidCallback? onToggleShuffle;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleVideoLoop;
  final ValueChanged<Duration>? onDurationSelected;
  final ValueChanged<double>? onPlaybackSpeedSelected;
  final ValueChanged<Duration>? onSeek;
  final MediaPlaybackControlVisibility? playbackVisibility;
  final bool showPlaybackForImages;
  final Widget? footer;
  final bool showBottomControls;
  final VideoBottomControlsConfig? bottomControlsConfig;

  /// Factory method for full-screen viewer overlay
  factory BaseMediaViewerOverlay.fullScreen({
    Key? key,
    required MediaEntity? media,
    required List<TagEntity> tags,
    required Set<String> selectedTagIds,
    required ValueChanged<TagEntity>? onTagTapped,
    required Widget? closeButton,
    required Widget? helpButton,
    required Widget? favoriteButton,
    required Widget? tagEditorButton,
    required MediaProgressData progress,
    required MediaPlaybackData playback,
    required VoidCallback? onPlayPause,
    required VoidCallback? onNext,
    required VoidCallback? onPrevious,
    required VoidCallback? onToggleLoop,
    required VoidCallback? onToggleShuffle,
    required VoidCallback? onToggleMute,
    required VoidCallback? onToggleVideoLoop,
    required ValueChanged<Duration>? onDurationSelected,
    required ValueChanged<double>? onPlaybackSpeedSelected,
    required ValueChanged<Duration>? onSeek,
    required MediaPlaybackControlVisibility? playbackVisibility,
    required bool showPlaybackForImages,
    required bool showBottomControlsForVideos,
    required VideoBottomControlsConfig? bottomControlsConfig,
  }) {
    return BaseMediaViewerOverlay._(
      key: key,
      media: media,
      tags: tags,
      selectedTagIds: selectedTagIds,
      onTagTapped: onTagTapped,
      leadingAction: closeButton,
      trailingActions: [
        if (helpButton != null) helpButton,
        if (favoriteButton != null) favoriteButton,
        if (tagEditorButton != null) tagEditorButton,
      ],
      progress: progress,
      playback: playback,
      onPlayPause: onPlayPause,
      onNext: onNext,
      onPrevious: onPrevious,
      onToggleLoop: onToggleLoop,
      onToggleShuffle: onToggleShuffle,
      onToggleMute: onToggleMute,
      onToggleVideoLoop: onToggleVideoLoop,
      onDurationSelected: onDurationSelected,
      onPlaybackSpeedSelected: onPlaybackSpeedSelected,
      onSeek: onSeek,
      playbackVisibility: playbackVisibility,
      showPlaybackForImages: showPlaybackForImages,
      footer: null,
      showBottomControls: showBottomControlsForVideos,
      bottomControlsConfig: bottomControlsConfig,
    );
  }

  /// Factory method for slideshow overlay
  factory BaseMediaViewerOverlay.slideshow({
    Key? key,
    required MediaEntity? media,
    required List<TagEntity> tags,
    required Set<String> selectedTagIds,
    required ValueChanged<TagEntity>? onTagTapped,
    required Widget? closeButton,
    required Widget? favoriteButton,
    required MediaProgressData progress,
    required MediaPlaybackData playback,
    required VoidCallback? onPlayPause,
    required VoidCallback? onNext,
    required VoidCallback? onPrevious,
    required VoidCallback? onToggleLoop,
    required VoidCallback? onToggleShuffle,
    required VoidCallback? onToggleMute,
    required VoidCallback? onToggleVideoLoop,
    required ValueChanged<Duration>? onDurationSelected,
    required ValueChanged<double>? onPlaybackSpeedSelected,
    required ValueChanged<Duration>? onSeek,
    required MediaPlaybackControlVisibility? playbackVisibility,
    required bool showPlaybackForImages,
    required Widget? footer,
    required bool showBottomControls,
    required VideoBottomControlsConfig? bottomControlsConfig,
  }) {
    return BaseMediaViewerOverlay._(
      key: key,
      media: media,
      tags: tags,
      selectedTagIds: selectedTagIds,
      onTagTapped: onTagTapped,
      leadingAction: closeButton,
      trailingActions: [if (favoriteButton != null) favoriteButton],
      progress: progress,
      playback: playback,
      onPlayPause: onPlayPause,
      onNext: onNext,
      onPrevious: onPrevious,
      onToggleLoop: onToggleLoop,
      onToggleShuffle: onToggleShuffle,
      onToggleMute: onToggleMute,
      onToggleVideoLoop: onToggleVideoLoop,
      onDurationSelected: onDurationSelected,
      onPlaybackSpeedSelected: onPlaybackSpeedSelected,
      onSeek: onSeek,
      playbackVisibility: playbackVisibility,
      showPlaybackForImages: showPlaybackForImages,
      footer: footer,
      showBottomControls: showBottomControls,
      bottomControlsConfig: bottomControlsConfig,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = media?.type == MediaType.video;

    return Stack(
      children: [
        MediaViewerOverlay(
          media: media,
          tags: tags,
          selectedTagIds: selectedTagIds,
          onTagTapped: onTagTapped,
          leadingAction: leadingAction,
          trailingActions: trailingActions,
          progress:
              progress ??
              const MediaProgressData(currentIndex: 0, totalItems: 0),
          playback:
              playback ??
              const MediaPlaybackData(
                isPlaying: false,
                isLooping: false,
                isShuffleEnabled: false,
                isMuted: false,
              ),
          onPlayPause: onPlayPause,
          onNext: onNext,
          onPrevious: onPrevious,
          onToggleLoop: onToggleLoop,
          onToggleShuffle: onToggleShuffle,
          onToggleMute: onToggleMute,
          onToggleVideoLoop: onToggleVideoLoop,
          onDurationSelected: onDurationSelected,
          onPlaybackSpeedSelected: onPlaybackSpeedSelected,
          onSeek: onSeek,
          playbackVisibility: playbackVisibility,
          showPlaybackForImages: showPlaybackForImages,
        ),
        if (footer != null)
          Positioned(bottom: 80, left: 16, right: 16, child: footer!),
        if (showBottomControls && bottomControlsConfig != null && isVideo)
          VideoBottomControls(config: bottomControlsConfig!),
      ],
    );
  }
}
