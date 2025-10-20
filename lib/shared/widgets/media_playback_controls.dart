import 'package:flutter/material.dart';

/// Builder callback for customizing the progress presentation of the controls.
typedef MediaPlaybackProgressBuilder = Widget Function(
  BuildContext context,
  double progress,
  MediaPlaybackControlStyle style,
);

/// Icon configuration used by [MediaPlaybackControls].
class MediaPlaybackControlIcons {
  const MediaPlaybackControlIcons({
    this.play = Icons.play_arrow,
    this.pause = Icons.pause,
    this.previous = Icons.skip_previous,
    this.next = Icons.skip_next,
    this.loopEnabled = Icons.repeat,
    this.loopDisabled = Icons.repeat_one,
    this.shuffle = Icons.shuffle,
    this.muteEnabled = Icons.volume_off,
    this.muteDisabled = Icons.volume_up,
    this.videoLoop = Icons.repeat_one,
  });

  final IconData play;
  final IconData pause;
  final IconData previous;
  final IconData next;
  final IconData loopEnabled;
  final IconData loopDisabled;
  final IconData shuffle;
  final IconData muteEnabled;
  final IconData muteDisabled;
  final IconData videoLoop;
}

/// Visibility flags for the individual controls.
class MediaPlaybackControlVisibility {
  const MediaPlaybackControlVisibility({
    this.showPrevious = true,
    this.showPlayPause = true,
    this.showNext = true,
    this.showLoop = true,
    this.showShuffle = true,
    this.showMute = true,
    this.showDurationSlider = true,
    this.showProgressBar = true,
    this.showVideoLoop = false,
  });

  final bool showPrevious;
  final bool showPlayPause;
  final bool showNext;
  final bool showLoop;
  final bool showShuffle;
  final bool showMute;
  final bool showDurationSlider;
  final bool showProgressBar;
  final bool showVideoLoop;

  MediaPlaybackControlVisibility copyWith({
    bool? showPrevious,
    bool? showPlayPause,
    bool? showNext,
    bool? showLoop,
    bool? showShuffle,
    bool? showMute,
    bool? showDurationSlider,
    bool? showProgressBar,
    bool? showVideoLoop,
  }) {
    return MediaPlaybackControlVisibility(
      showPrevious: showPrevious ?? this.showPrevious,
      showPlayPause: showPlayPause ?? this.showPlayPause,
      showNext: showNext ?? this.showNext,
      showLoop: showLoop ?? this.showLoop,
      showShuffle: showShuffle ?? this.showShuffle,
      showMute: showMute ?? this.showMute,
      showDurationSlider: showDurationSlider ?? this.showDurationSlider,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      showVideoLoop: showVideoLoop ?? this.showVideoLoop,
    );
  }
}

/// Availability flags for enabling and disabling the controls without hiding them.
class MediaPlaybackControlAvailability {
  const MediaPlaybackControlAvailability({
    this.enablePrevious = true,
    this.enablePlayPause = true,
    this.enableNext = true,
    this.enableLoop = true,
    this.enableShuffle = true,
    this.enableMute = true,
    this.enableDurationSlider = true,
    this.enableVideoLoop = true,
  });

  final bool enablePrevious;
  final bool enablePlayPause;
  final bool enableNext;
  final bool enableLoop;
  final bool enableShuffle;
  final bool enableMute;
  final bool enableDurationSlider;
  final bool enableVideoLoop;

  MediaPlaybackControlAvailability copyWith({
    bool? enablePrevious,
    bool? enablePlayPause,
    bool? enableNext,
    bool? enableLoop,
    bool? enableShuffle,
    bool? enableMute,
    bool? enableDurationSlider,
    bool? enableVideoLoop,
  }) {
    return MediaPlaybackControlAvailability(
      enablePrevious: enablePrevious ?? this.enablePrevious,
      enablePlayPause: enablePlayPause ?? this.enablePlayPause,
      enableNext: enableNext ?? this.enableNext,
      enableLoop: enableLoop ?? this.enableLoop,
      enableShuffle: enableShuffle ?? this.enableShuffle,
      enableMute: enableMute ?? this.enableMute,
      enableDurationSlider: enableDurationSlider ?? this.enableDurationSlider,
      enableVideoLoop: enableVideoLoop ?? this.enableVideoLoop,
    );
  }
}

/// Theming configuration for the controls surface.
class MediaPlaybackControlStyle {
  const MediaPlaybackControlStyle({
    this.iconTheme = const IconThemeData(color: Colors.white, size: 32),
    this.playPauseIconSize = 48,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.white,
    this.durationLabelTextStyle = const TextStyle(color: Colors.white),
    this.sliderActiveTrackColor = Colors.blueAccent,
    this.sliderInactiveTrackColor = Colors.white24,
    this.sliderThumbColor = Colors.white,
    this.sliderOverlayColor = Colors.white24,
    this.progressColor = Colors.white,
    this.progressBackgroundColor = Colors.white30,
    this.controlSpacing = 16,
    this.sectionSpacing = 32,
    this.durationSliderWidth = 240,
    this.progressBarHeight = 4,
    this.expandProgressBar = true,
  });

  final IconThemeData iconTheme;
  final double playPauseIconSize;
  final Color activeColor;
  final Color inactiveColor;
  final TextStyle durationLabelTextStyle;
  final Color sliderActiveTrackColor;
  final Color sliderInactiveTrackColor;
  final Color sliderThumbColor;
  final Color sliderOverlayColor;
  final Color progressColor;
  final Color progressBackgroundColor;
  final double controlSpacing;
  final double sectionSpacing;
  final double durationSliderWidth;
  final double progressBarHeight;
  final bool expandProgressBar;
}

/// A configurable control surface for media playback or slideshows.
class MediaPlaybackControls extends StatelessWidget {
  const MediaPlaybackControls({
    super.key,
    required this.isPlaying,
    this.isLooping = false,
    this.isShuffleEnabled = false,
    this.isMuted = false,
    this.isVideoLooping = false,
    this.progress,
    this.minDuration = const Duration(seconds: 1),
    this.maxDuration = const Duration(seconds: 10),
    this.currentItemDuration = const Duration(seconds: 5),
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onToggleLoop,
    this.onToggleShuffle,
    this.onToggleMute,
    this.onToggleVideoLoop,
    this.onDurationSelected,
    this.visibility = const MediaPlaybackControlVisibility(),
    this.availability = const MediaPlaybackControlAvailability(),
    this.icons = const MediaPlaybackControlIcons(),
    this.style = const MediaPlaybackControlStyle(),
    this.progressBuilder,
  });

  final bool isPlaying;
  final bool isLooping;
  final bool isShuffleEnabled;
  final bool isMuted;
  final bool isVideoLooping;
  final double? progress;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration currentItemDuration;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleLoop;
  final VoidCallback? onToggleShuffle;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleVideoLoop;
  final ValueChanged<Duration>? onDurationSelected;
  final MediaPlaybackControlVisibility visibility;
  final MediaPlaybackControlAvailability availability;
  final MediaPlaybackControlIcons icons;
  final MediaPlaybackControlStyle style;
  final MediaPlaybackProgressBuilder? progressBuilder;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addControlSpacing() {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: style.controlSpacing));
      }
    }

    void addSectionSpacing() {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: style.sectionSpacing));
      }
    }

    if (visibility.showPrevious) {
      addControlSpacing();
      children.add(_buildIconButton(
        icon: icons.previous,
        tooltip: 'Previous',
        onPressed: availability.enablePrevious ? onPrevious : null,
        isActive: false,
      ));
    }

    if (visibility.showPlayPause) {
      addControlSpacing();
      children.add(_buildPlayPauseButton());
    }

    if (visibility.showNext) {
      addControlSpacing();
      children.add(_buildIconButton(
        icon: icons.next,
        tooltip: 'Next',
        onPressed: availability.enableNext ? onNext : null,
        isActive: false,
      ));
    }

    if (visibility.showLoop) {
      addSectionSpacing();
      children.add(_buildIconButton(
        icon: isLooping ? icons.loopEnabled : icons.loopDisabled,
        tooltip: isLooping ? 'Disable loop' : 'Enable loop',
        onPressed: availability.enableLoop ? onToggleLoop : null,
        isActive: isLooping,
      ));
    }

    if (visibility.showShuffle) {
      addControlSpacing();
      children.add(_buildIconButton(
        icon: icons.shuffle,
        tooltip: isShuffleEnabled ? 'Disable shuffle' : 'Enable shuffle',
        onPressed: availability.enableShuffle ? onToggleShuffle : null,
        isActive: isShuffleEnabled,
      ));
    }

    if (visibility.showMute) {
      addControlSpacing();
      children.add(_buildIconButton(
        icon: isMuted ? icons.muteEnabled : icons.muteDisabled,
        tooltip: isMuted ? 'Unmute' : 'Mute',
        onPressed: availability.enableMute ? onToggleMute : null,
        isActive: false,
      ));
    }

    if (visibility.showDurationSlider) {
      addSectionSpacing();
      children.add(_buildDurationSlider(context));
    }

    if (visibility.showProgressBar) {
      addSectionSpacing();
      final progressWidget = _buildProgressBar(context);
      if (style.expandProgressBar) {
        children.add(Expanded(child: progressWidget));
      } else {
        children.add(progressWidget);
      }

      if (visibility.showVideoLoop) {
        addControlSpacing();
        children.add(_buildIconButton(
          icon: icons.videoLoop,
          tooltip:
              isVideoLooping ? 'Disable video loop' : 'Loop current video',
          onPressed: availability.enableVideoLoop ? onToggleVideoLoop : null,
          isActive: isVideoLooping,
        ));
      }
    } else if (visibility.showVideoLoop) {
      addSectionSpacing();
      children.add(_buildIconButton(
        icon: icons.videoLoop,
        tooltip: isVideoLooping ? 'Disable video loop' : 'Loop current video',
        onPressed: availability.enableVideoLoop ? onToggleVideoLoop : null,
        isActive: isVideoLooping,
      ));
    }

    return IconTheme(
      data: style.iconTheme,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: children,
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return IconButton(
      iconSize: style.playPauseIconSize,
      icon: Icon(
        isPlaying ? icons.pause : icons.play,
        color: style.inactiveColor,
      ),
      onPressed: availability.enablePlayPause ? onPlayPause : null,
      tooltip: isPlaying ? 'Pause' : 'Play',
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool isActive,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? style.activeColor : style.inactiveColor,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  Widget _buildDurationSlider(BuildContext context) {
    final minSeconds = minDuration.inSeconds;
    final maxSeconds = maxDuration.inSeconds;

    final safeMin = minSeconds < 0 ? 0 : minSeconds;
    final safeMax = maxSeconds <= safeMin ? safeMin + 1 : maxSeconds;

    final currentSeconds = currentItemDuration.inSeconds;
    final clampedSeconds = currentSeconds.clamp(safeMin, safeMax).toInt();

    final slider = SizedBox(
      width: style.durationSliderWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Slide duration: ${clampedSeconds}s',
            style: style.durationLabelTextStyle,
          ),
          Row(
            children: [
              Icon(Icons.timer, color: style.inactiveColor),
              SizedBox(width: style.controlSpacing / 2),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: style.sliderActiveTrackColor,
                    inactiveTrackColor: style.sliderInactiveTrackColor,
                    thumbColor: style.sliderThumbColor,
                    overlayColor: style.sliderOverlayColor,
                  ),
                  child: Slider(
                    min: safeMin.toDouble(),
                    max: safeMax.toDouble(),
                    divisions: safeMax - safeMin,
                    value: clampedSeconds.toDouble(),
                    label: '${clampedSeconds}s',
                    onChanged: availability.enableDurationSlider &&
                            onDurationSelected != null
                        ? (value) {
                            final rounded = value.round();
                            final seconds =
                                rounded.clamp(safeMin, safeMax).toInt();
                            onDurationSelected!(Duration(seconds: seconds));
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (availability.enableDurationSlider) {
      return slider;
    }

    return IgnorePointer(ignoring: true, child: slider);
  }

  Widget _buildProgressBar(BuildContext context) {
    final progressValue = (progress ?? 0.0).clamp(0.0, 1.0);
    final widget = progressBuilder?.call(context, progressValue, style) ??
        _DefaultProgressBar(
          progress: progressValue,
          style: style,
        );
    return SizedBox(height: style.progressBarHeight, child: widget);
  }
}

class _DefaultProgressBar extends StatelessWidget {
  const _DefaultProgressBar({
    required this.progress,
    required this.style,
  });

  final double progress;
  final MediaPlaybackControlStyle style;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: style.progressBackgroundColor,
      valueColor: AlwaysStoppedAnimation<Color>(style.progressColor),
    );
  }
}
