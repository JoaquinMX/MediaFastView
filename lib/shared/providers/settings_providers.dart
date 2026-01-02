import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/domain/entities/app_settings.dart';
import '../../features/settings/domain/entities/playback_settings.dart';
import '../../features/settings/presentation/view_models/settings_view_model.dart';

final settingsProvider = Provider<AsyncValue<AppSettings>>((ref) {
  return ref.watch(settingsViewModelProvider);
});

final themeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.themeMode,
    orElse: () => const AppSettings.initial().themeMode,
  );
});

final thumbnailCachingProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.thumbnailCachingEnabled,
    orElse: () => const AppSettings.initial().thumbnailCachingEnabled,
  );
});

final deleteFromSourceProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.deleteFromSourceEnabled,
    orElse: () => const AppSettings.initial().deleteFromSourceEnabled,
  );
});

final videoPlaybackSettingsProvider = Provider<PlaybackSettings>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.playbackSettings,
    orElse: () => const PlaybackSettings.initial(),
  );
});

final autoNavigateSiblingDirectoriesProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.autoNavigateSiblingDirectories,
    orElse: () => const AppSettings.initial().autoNavigateSiblingDirectories,
  );
});

final slideshowControlsHideDelayProvider = Provider<Duration>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.slideshowControlsHideDelay,
    orElse: () => const AppSettings.initial().slideshowControlsHideDelay,
  );
});
