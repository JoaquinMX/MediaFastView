import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/media_lookup_mode.dart';
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

final thumbnailDiskCacheEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.thumbnailDiskCacheEnabled,
    orElse: () => const AppSettings.initial().thumbnailDiskCacheEnabled,
  );
});

final imageLookupHistoryEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.imageLookupHistoryEnabled,
    orElse: () => const AppSettings.initial().imageLookupHistoryEnabled,
  );
});

final mediaLookupModeProvider = Provider<MediaLookupMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.mediaLookupMode,
    orElse: () => const AppSettings.initial().mediaLookupMode,
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

final navigateToSiblingAfterDirectoryDeleteProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.navigateToSiblingAfterDirectoryDelete,
    orElse: () =>
        const AppSettings.initial().navigateToSiblingAfterDirectoryDelete,
  );
});

final showDirectoryTaggedMediaCountsProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.showDirectoryTaggedMediaCounts,
    orElse: () => const AppSettings.initial().showDirectoryTaggedMediaCounts,
  );
});

final slideshowControlsHideDelayProvider = Provider<Duration>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.maybeWhen(
    data: (value) => value.slideshowControlsHideDelay,
    orElse: () => const AppSettings.initial().slideshowControlsHideDelay,
  );
});
