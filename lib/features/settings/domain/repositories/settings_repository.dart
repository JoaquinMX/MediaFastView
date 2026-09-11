import 'package:flutter/material.dart';

import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';
import '../entities/app_settings.dart';
import '../entities/playback_settings.dart';

/// Abstraction for persisting and retrieving user settings.
abstract class SettingsRepository {
  Future<AppSettings> loadSettings();

  Future<void> saveThemeMode(ThemeMode themeMode);

  Future<void> saveThumbnailDiskCacheEnabled(bool enabled);

  Future<void> saveImageLookupHistoryEnabled(bool enabled);

  Future<void> saveMediaLookupMode(MediaLookupMode mode);

  Future<void> saveVideoFrameLookupPrecision(
    VideoFrameLookupPrecision precision,
  );

  Future<void> saveDeleteFromSourceEnabled(bool enabled);

  Future<void> savePlaybackSettings(PlaybackSettings settings);

  Future<void> saveAutoNavigateSiblingDirectories(bool enabled);

  Future<void> saveNavigateToSiblingAfterDirectoryDelete(bool enabled);

  Future<void> saveShowDirectoryTaggedMediaCounts(bool enabled);

  Future<void> saveSlideshowControlsHideDelay(Duration delay);
}
