import 'package:flutter/material.dart';

import '../entities/app_settings.dart';
import '../entities/playback_settings.dart';

/// Abstraction for persisting and retrieving user settings.
abstract class SettingsRepository {
  Future<AppSettings> loadSettings();

  Future<void> saveThemeMode(ThemeMode themeMode);

  Future<void> saveThumbnailCachingEnabled(bool enabled);

  Future<void> saveDeleteFromSourceEnabled(bool enabled);

  Future<void> savePlaybackSettings(PlaybackSettings settings);

  Future<void> saveAutoNavigateSiblingDirectories(bool enabled);

  Future<void> saveSlideshowControlsHideDelay(Duration delay);
}
