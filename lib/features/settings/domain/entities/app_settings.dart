import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/media_lookup_mode.dart';
import 'playback_settings.dart';

const int slideshowControlsHideDelayMinSeconds = 1;
const int slideshowControlsHideDelayMaxSeconds = 30;

/// Aggregates user preferences that can be configured from the settings UI.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.thumbnailDiskCacheEnabled,
    required this.imageLookupHistoryEnabled,
    required this.mediaLookupMode,
    required this.deleteFromSourceEnabled,
    required this.playbackSettings,
    required this.autoNavigateSiblingDirectories,
    required this.navigateToSiblingAfterDirectoryDelete,
    required this.showDirectoryTaggedMediaCounts,
    required this.slideshowControlsHideDelay,
  });

  const AppSettings.initial()
    : themeMode = ThemeMode.system,
      thumbnailDiskCacheEnabled = true,
      imageLookupHistoryEnabled = false,
      mediaLookupMode = MediaLookupMode.mediaMatches,
      deleteFromSourceEnabled = false,
      playbackSettings = const PlaybackSettings.initial(),
      autoNavigateSiblingDirectories = false,
      navigateToSiblingAfterDirectoryDelete = false,
      showDirectoryTaggedMediaCounts = false,
      slideshowControlsHideDelay = AppConfig.defaultSlideshowControlsHideDelay;

  final ThemeMode themeMode;

  /// Whether generated image and video previews are persisted to disk.
  final bool thumbnailDiskCacheEnabled;
  final bool imageLookupHistoryEnabled;
  final MediaLookupMode mediaLookupMode;
  final bool deleteFromSourceEnabled;
  final PlaybackSettings playbackSettings;
  final bool autoNavigateSiblingDirectories;

  /// When enabled, deleting the directory currently being viewed navigates to
  /// a sibling directory (next, or previous when at the end) instead of popping
  /// back to the previous route. Falls back to popping when there are no
  /// siblings.
  final bool navigateToSiblingAfterDirectoryDelete;

  final bool showDirectoryTaggedMediaCounts;
  final Duration slideshowControlsHideDelay;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? thumbnailDiskCacheEnabled,
    bool? imageLookupHistoryEnabled,
    MediaLookupMode? mediaLookupMode,
    bool? deleteFromSourceEnabled,
    PlaybackSettings? playbackSettings,
    bool? autoNavigateSiblingDirectories,
    bool? navigateToSiblingAfterDirectoryDelete,
    bool? showDirectoryTaggedMediaCounts,
    Duration? slideshowControlsHideDelay,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      thumbnailDiskCacheEnabled:
          thumbnailDiskCacheEnabled ?? this.thumbnailDiskCacheEnabled,
      imageLookupHistoryEnabled:
          imageLookupHistoryEnabled ?? this.imageLookupHistoryEnabled,
      mediaLookupMode: mediaLookupMode ?? this.mediaLookupMode,
      deleteFromSourceEnabled:
          deleteFromSourceEnabled ?? this.deleteFromSourceEnabled,
      playbackSettings: playbackSettings ?? this.playbackSettings,
      autoNavigateSiblingDirectories:
          autoNavigateSiblingDirectories ?? this.autoNavigateSiblingDirectories,
      navigateToSiblingAfterDirectoryDelete:
          navigateToSiblingAfterDirectoryDelete ??
          this.navigateToSiblingAfterDirectoryDelete,
      showDirectoryTaggedMediaCounts:
          showDirectoryTaggedMediaCounts ?? this.showDirectoryTaggedMediaCounts,
      slideshowControlsHideDelay:
          slideshowControlsHideDelay ?? this.slideshowControlsHideDelay,
    );
  }
}
