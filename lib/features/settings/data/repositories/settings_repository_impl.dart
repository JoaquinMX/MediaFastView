import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/playback_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Implementation of [SettingsRepository] using [SharedPreferences].
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl();

  static const String _themeKey = 'theme_mode';
  static const String _thumbnailCachingKey = 'thumbnail_caching_enabled';
  static const String _deleteFromSourceKey = 'delete_from_source_enabled';
  static const String _autoplayKey = 'video_autoplay_enabled';
  static const String _loopKey = 'video_loop_enabled';
  static const String _autoNavigateKey = 'auto_navigate_sibling_directories';
  static const String _slideshowControlsHideDelayKey =
      'slideshowControlsHideDelay';

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    final autoplay = prefs.getBool(_autoplayKey) ?? false;
    final loop = prefs.getBool(_loopKey) ?? false;
    final thumbnailCachingEnabled = prefs.getBool(_thumbnailCachingKey) ?? true;
    final deleteFromSourceEnabled = prefs.getBool(_deleteFromSourceKey) ?? false;
    final autoNavigateSiblingDirectories =
        prefs.getBool(_autoNavigateKey) ?? false;
    final storedHideDelay = prefs.getInt(_slideshowControlsHideDelayKey);
    final hideDelaySeconds = (storedHideDelay ??
            const AppSettings.initial().slideshowControlsHideDelay.inSeconds)
        .clamp(
          slideshowControlsHideDelayMinSeconds,
          slideshowControlsHideDelayMaxSeconds,
        )
        .toInt();

    return AppSettings(
      themeMode: ThemeMode.values[themeIndex],
      thumbnailCachingEnabled: thumbnailCachingEnabled,
      deleteFromSourceEnabled: deleteFromSourceEnabled,
      playbackSettings: PlaybackSettings(
        autoplayVideos: autoplay,
        loopVideos: loop,
      ),
      autoNavigateSiblingDirectories: autoNavigateSiblingDirectories,
      slideshowControlsHideDelay: Duration(
        seconds: hideDelaySeconds,
      ),
    );
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, themeMode.index);
  }

  @override
  Future<void> saveThumbnailCachingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_thumbnailCachingKey, enabled);
  }

  @override
  Future<void> saveDeleteFromSourceEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deleteFromSourceKey, enabled);
  }

  @override
  Future<void> savePlaybackSettings(PlaybackSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplayKey, settings.autoplayVideos);
    await prefs.setBool(_loopKey, settings.loopVideos);
  }

  @override
  Future<void> saveAutoNavigateSiblingDirectories(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNavigateKey, enabled);
  }

  @override
  Future<void> saveSlideshowControlsHideDelay(Duration delay) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_slideshowControlsHideDelayKey, delay.inSeconds);
  }
}
