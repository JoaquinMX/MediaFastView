import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/tagging/domain/entities/tag_entity.dart';
import '../widgets/media_playback_controls.dart';
import '../widgets/media_progress_indicator.dart';
import '../widgets/tag_overlay.dart';

/// Data for progress indicator display.
class MediaProgressData {
  const MediaProgressData({
    required this.currentIndex,
    required this.totalItems,
    this.progress,
    this.showProgressBar = true,
    this.showCounter = true,
  });

  final int currentIndex;
  final int totalItems;
  final double? progress;
  final bool showProgressBar;
  final bool showCounter;
}

/// Data for playback controls display.
class MediaPlaybackData {
  const MediaPlaybackData({
    required this.isPlaying,
    required this.isLooping,
    required this.isShuffleEnabled,
    required this.isMuted,
    this.isVideoLooping = false,
    this.playbackSpeed,
    this.playbackSpeedOptions = const [1.0, 2.0, 2.5, 3.0, 4.0],
    this.progress,
    this.minDuration = const Duration(seconds: 1),
    this.maxDuration = const Duration(seconds: 10),
    this.currentItemDuration = const Duration(seconds: 5),
    this.totalDuration,
  });

  final bool isPlaying;
  final bool isLooping;
  final bool isShuffleEnabled;
  final bool isMuted;
  final bool isVideoLooping;
  final double? playbackSpeed;
  final List<double> playbackSpeedOptions;
  final double? progress;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration currentItemDuration;
  final Duration? totalDuration;
}

/// Styling configuration for media viewer overlay.
class MediaOverlayStyle {
  const MediaOverlayStyle({
    this.topGradientAlpha = 0.7,
    this.bottomGradientAlpha = 0.8,
    this.padding = 16,
    this.sectionSpacing = 12,
    this.footerSpacing = 8,
    this.counterTextStyle,
    this.progressColor,
    this.progressBackgroundColor,
  });

  final double topGradientAlpha;
  final double bottomGradientAlpha;
  final double padding;
  final double sectionSpacing;
  final double footerSpacing;
  final TextStyle? counterTextStyle;
  final Color? progressColor;
  final Color? progressBackgroundColor;
}

/// A configurable overlay widget for media viewing interfaces.
///
/// Provides top and bottom control surfaces with gradients, progress indicators,
/// playback controls, tag overlays, and customizable action buttons.
/// Designed for use in both full-screen viewers and slideshows.
class MediaViewerOverlay extends ConsumerWidget {
  const MediaViewerOverlay({
    super.key,
    required this.media,
    required this.tags,
    required this.selectedTagIds,
    required this.progress,
    required this.playback,
    this.leadingAction,
    this.trailingActions = const [],
    this.tagHeaderTrailing,
    this.onTagTapped,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onToggleLoop,
    this.onToggleShuffle,
    this.onToggleMute,
    this.onToggleVideoLoop,
    this.onDurationSelected,
    this.onPlaybackSpeedSelected,
    this.onSeek,
    this.playbackVisibility,
    this.playbackAvailability,
    this.playbackStyle,
    this.footer,
    this.style,
    this.showPlaybackForImages = false,
  });

  final MediaEntity? media;
  final List<TagEntity> tags;
  final Set<String> selectedTagIds;
  final MediaProgressData progress;
  final MediaPlaybackData playback;
  final Widget? leadingAction;
  final List<Widget> trailingActions;
  final Widget? tagHeaderTrailing;
  final ValueChanged<TagEntity>? onTagTapped;
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
  final MediaPlaybackControlAvailability? playbackAvailability;
  final MediaPlaybackControlStyle? playbackStyle;
  final Widget? footer;
  final MediaOverlayStyle? style;
  final bool showPlaybackForImages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = this.style ?? const MediaOverlayStyle();
    final isVideo = media?.type == MediaType.video;

    final topDisplay = _OverlayDisplay(
      alignment: Alignment.topCenter,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: style.topGradientAlpha),
          Colors.transparent,
        ],
      ),
      padding: EdgeInsets.all(style.padding),
      safeAreaTop: true,
      sections: [
        _HeaderSection(
          leadingAction: leadingAction,
          trailingActions: trailingActions,
        ),
        if (media != null)
          _TagSection(
            media: media!,
            tags: tags,
            selectedTagIds: selectedTagIds,
            trailing: tagHeaderTrailing,
            onTagTapped: onTagTapped,
          ),
      ],
      sectionSpacing: style.sectionSpacing,
    );

    final bottomDisplay = _OverlayDisplay(
      alignment: Alignment.bottomCenter,
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: style.bottomGradientAlpha),
          Colors.transparent,
        ],
      ),
      padding: EdgeInsets.all(style.padding),
      safeAreaBottom: true,
      sections: [
        _ProgressSection(
          progress: progress,
          counterTextStyle: style.counterTextStyle,
          progressColor: style.progressColor,
          progressBackgroundColor: style.progressBackgroundColor,
        ),
        _PlaybackSection(
          playback: playback,
          isVideo: isVideo,
          showPlaybackForImages: showPlaybackForImages,
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
          visibility: playbackVisibility,
          availability: playbackAvailability,
          style: playbackStyle,
        ),
      ],
      footer: footer,
      footerSpacing: style.footerSpacing,
    );

    return Stack(children: [topDisplay, bottomDisplay]);
  }
}

class _OverlayDisplay extends StatelessWidget {
  const _OverlayDisplay({
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

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({this.leadingAction, this.trailingActions = const []});

  final Widget? leadingAction;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingAction != null) leadingAction!,
        const Spacer(),
        ...trailingActions,
      ],
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.media,
    required this.tags,
    required this.selectedTagIds,
    this.trailing,
    this.onTagTapped,
  });

  final MediaEntity media;
  final List<TagEntity> tags;
  final Set<String> selectedTagIds;
  final Widget? trailing;
  final ValueChanged<TagEntity>? onTagTapped;

  @override
  Widget build(BuildContext context) {
    return TagOverlay(
      tags: tags,
      selectedTagIds: selectedTagIds,
      onTagTapped: onTagTapped,
      trailing: trailing,
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    this.counterTextStyle,
    this.progressColor,
    this.progressBackgroundColor,
  });

  final MediaProgressData progress;
  final TextStyle? counterTextStyle;
  final Color? progressColor;
  final Color? progressBackgroundColor;

  @override
  Widget build(BuildContext context) {
    if (!progress.showCounter && !progress.showProgressBar) {
      return const SizedBox.shrink();
    }

    return MediaProgressIndicator(
      currentIndex: progress.currentIndex,
      totalItems: progress.totalItems,
      progress: progress.progress,
      showCounter: progress.showCounter,
      showProgressBar: progress.showProgressBar,
      counterTextStyle: counterTextStyle,
      progressColor: progressColor ?? Colors.white,
      backgroundColor:
          progressBackgroundColor ?? Colors.white.withValues(alpha: 0.3),
    );
  }
}

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.playback,
    required this.isVideo,
    this.showPlaybackForImages = false,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onToggleLoop,
    this.onToggleShuffle,
    this.onToggleMute,
    this.onToggleVideoLoop,
    this.onDurationSelected,
    this.onPlaybackSpeedSelected,
    this.onSeek,
    this.visibility,
    this.availability,
    this.style,
  });

  final MediaPlaybackData playback;
  final bool isVideo;
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
  final MediaPlaybackControlVisibility? visibility;
  final MediaPlaybackControlAvailability? availability;
  final MediaPlaybackControlStyle? style;
  final bool showPlaybackForImages;

  @override
  Widget build(BuildContext context) {
    if (!isVideo && !showPlaybackForImages) {
      return const SizedBox.shrink();
    }

    return MediaPlaybackControls(
      isPlaying: playback.isPlaying,
      isLooping: playback.isLooping,
      isShuffleEnabled: playback.isShuffleEnabled,
      isMuted: playback.isMuted,
      isVideoLooping: playback.isVideoLooping,
      playbackSpeed: playback.playbackSpeed,
      playbackSpeedOptions: playback.playbackSpeedOptions,
      progress: playback.progress,
      minDuration: playback.minDuration,
      maxDuration: playback.maxDuration,
      currentItemDuration: playback.currentItemDuration,
      totalDuration: playback.totalDuration,
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
      visibility: visibility ?? const MediaPlaybackControlVisibility(),
      availability: availability ?? const MediaPlaybackControlAvailability(),
      style: style ?? const MediaPlaybackControlStyle(),
    );
  }
}
