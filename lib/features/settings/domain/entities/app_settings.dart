import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import 'playback_settings.dart';

const int slideshowControlsHideDelayMinSeconds = 1;
const int slideshowControlsHideDelayMaxSeconds = 30;

/// Aggregates user preferences that can be configured from the settings UI.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.thumbnailCachingEnabled,
    required this.deleteFromSourceEnabled,
    required this.playbackSettings,
    required this.autoNavigateSiblingDirectories,
    required this.slideshowControlsHideDelay,
  });

  const AppSettings.initial()
      : themeMode = ThemeMode.system,
        thumbnailCachingEnabled = true,
        deleteFromSourceEnabled = false,
        playbackSettings = const PlaybackSettings.initial(),
        autoNavigateSiblingDirectories = false,
        slideshowControlsHideDelay = AppConfig.defaultSlideshowControlsHideDelay;

  final ThemeMode themeMode;
  final bool thumbnailCachingEnabled;
  final bool deleteFromSourceEnabled;
  final PlaybackSettings playbackSettings;
  final bool autoNavigateSiblingDirectories;
  final Duration slideshowControlsHideDelay;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? thumbnailCachingEnabled,
    bool? deleteFromSourceEnabled,
    PlaybackSettings? playbackSettings,
    bool? autoNavigateSiblingDirectories,
    Duration? slideshowControlsHideDelay,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      thumbnailCachingEnabled:
          thumbnailCachingEnabled ?? this.thumbnailCachingEnabled,
      deleteFromSourceEnabled:
          deleteFromSourceEnabled ?? this.deleteFromSourceEnabled,
      playbackSettings: playbackSettings ?? this.playbackSettings,
      autoNavigateSiblingDirectories:
          autoNavigateSiblingDirectories ?? this.autoNavigateSiblingDirectories,
      slideshowControlsHideDelay:
          slideshowControlsHideDelay ?? this.slideshowControlsHideDelay,
    );
  }
}
