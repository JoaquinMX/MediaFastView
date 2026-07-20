import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/playback_settings.dart';
import '../../domain/use_cases/get_app_settings_use_case.dart';
import '../../domain/use_cases/update_auto_navigate_sibling_directories_use_case.dart';
import '../../domain/use_cases/update_delete_from_source_use_case.dart';
import '../../domain/use_cases/update_navigate_to_sibling_after_directory_delete_use_case.dart';
import '../../domain/use_cases/update_playback_settings_use_case.dart';
import '../../domain/use_cases/update_show_directory_tagged_media_counts_use_case.dart';
import '../../domain/use_cases/update_slideshow_controls_hide_delay_use_case.dart';
import '../../domain/use_cases/update_theme_mode_use_case.dart';
import '../../domain/use_cases/update_thumbnail_disk_cache_use_case.dart';
import '../../../media_library/domain/use_cases/clear_media_cache_use_case.dart';
import '../../../media_library/domain/use_cases/rescan_library_use_case.dart';
import '../../../tagging/domain/use_cases/clear_tag_assignments_use_case.dart';
import '../../../tagging/domain/use_cases/clear_tags_use_case.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/sidecar_providers.dart';
import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../sidecar/domain/entities/sidecar_result.dart';
import '../../../sidecar/domain/use_cases/export_sidecars_use_case.dart';
import '../../../sidecar/domain/use_cases/import_sidecars_use_case.dart';
import '../../../../core/services/logging_service.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, AppSettings>(
      SettingsViewModel.new,
    );

/// View model responsible for orchestrating settings interactions and
/// persistence via domain use cases.
class SettingsViewModel extends AsyncNotifier<AppSettings> {
  late final GetAppSettingsUseCase _getAppSettingsUseCase = ref.read(
    getAppSettingsUseCaseProvider,
  );
  late final UpdateThemeModeUseCase _updateThemeModeUseCase = ref.read(
    updateThemeModeUseCaseProvider,
  );
  late final UpdateThumbnailDiskCacheUseCase _updateThumbnailDiskCacheUseCase =
      ref.read(updateThumbnailDiskCacheUseCaseProvider);
  late final UpdateDeleteFromSourceUseCase _updateDeleteFromSourceUseCase = ref
      .read(updateDeleteFromSourceUseCaseProvider);
  late final UpdatePlaybackSettingsUseCase _updatePlaybackSettingsUseCase = ref
      .read(updatePlaybackSettingsUseCaseProvider);
  late final UpdateAutoNavigateSiblingDirectoriesUseCase
  _updateAutoNavigateSiblingDirectoriesUseCase = ref.read(
    updateAutoNavigateSiblingDirectoriesUseCaseProvider,
  );
  late final UpdateNavigateToSiblingAfterDirectoryDeleteUseCase
  _updateNavigateToSiblingAfterDirectoryDeleteUseCase = ref.read(
    updateNavigateToSiblingAfterDirectoryDeleteUseCaseProvider,
  );
  late final UpdateShowDirectoryTaggedMediaCountsUseCase
  _updateShowDirectoryTaggedMediaCountsUseCase = ref.read(
    updateShowDirectoryTaggedMediaCountsUseCaseProvider,
  );
  late final UpdateSlideshowControlsHideDelayUseCase
  _updateSlideshowControlsHideDelayUseCase = ref.read(
    updateSlideshowControlsHideDelayUseCaseProvider,
  );
  late final ClearMediaCacheUseCase _clearMediaCacheUseCase = ref.read(
    clearMediaCacheUseCaseProvider,
  );
  late final RescanLibraryUseCase _rescanLibraryUseCase = ref.read(
    rescanLibraryUseCaseProvider,
  );
  late final ClearTagAssignmentsUseCase _clearTagAssignmentsUseCase = ref.read(
    clearTagAssignmentsUseCaseProvider,
  );
  late final ClearTagsUseCase _clearTagsUseCase = ref.read(
    clearTagsUseCaseProvider,
  );
  late final TagCacheRefresher _tagCacheRefresher = ref.read(
    tagCacheRefresherProvider,
  );
  late final ExportSidecarsUseCase _exportSidecarsUseCase = ref.read(
    exportSidecarsUseCaseProvider,
  );
  late final ImportSidecarsUseCase _importSidecarsUseCase = ref.read(
    importSidecarsUseCaseProvider,
  );

  @override
  Future<AppSettings> build() {
    return _getAppSettingsUseCase();
  }

  Future<void> refreshSettings() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_getAppSettingsUseCase.call);
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _updateSetting(
      () => _updateThemeModeUseCase(themeMode),
      (settings) => settings.copyWith(themeMode: themeMode),
    );
  }

  Future<void> updateThumbnailDiskCache(bool enabled) async {
    await _updateSetting(
      () => _updateThumbnailDiskCacheUseCase(enabled),
      (settings) => settings.copyWith(thumbnailDiskCacheEnabled: enabled),
    );
  }

  Future<void> updateDeleteFromSource(bool enabled) async {
    await _updateSetting(
      () => _updateDeleteFromSourceUseCase(enabled),
      (settings) => settings.copyWith(deleteFromSourceEnabled: enabled),
    );
  }

  Future<void> updateAutoplayVideos(bool enabled) async {
    await _updatePlayback(
      (playback) => playback.copyWith(autoplayVideos: enabled),
    );
  }

  Future<void> updateLoopVideos(bool enabled) async {
    await _updatePlayback((playback) => playback.copyWith(loopVideos: enabled));
  }

  Future<void> updateStartMuted(bool enabled) async {
    await _updatePlayback((playback) => playback.copyWith(startMuted: enabled));
  }

  Future<void> updateAutoNavigateSiblingDirectories(bool enabled) async {
    await _updateSetting(
      () => _updateAutoNavigateSiblingDirectoriesUseCase(enabled),
      (settings) => settings.copyWith(autoNavigateSiblingDirectories: enabled),
    );
  }

  Future<void> updateNavigateToSiblingAfterDirectoryDelete(bool enabled) async {
    await _updateSetting(
      () => _updateNavigateToSiblingAfterDirectoryDeleteUseCase(enabled),
      (settings) =>
          settings.copyWith(navigateToSiblingAfterDirectoryDelete: enabled),
    );
  }

  Future<void> updateShowDirectoryTaggedMediaCounts(bool enabled) async {
    await _updateSetting(
      () => _updateShowDirectoryTaggedMediaCountsUseCase(enabled),
      (settings) => settings.copyWith(showDirectoryTaggedMediaCounts: enabled),
    );
  }

  Future<void> updateSlideshowControlsHideDelay(Duration delay) async {
    final clampedDelay = Duration(
      seconds: delay.inSeconds
          .clamp(
            slideshowControlsHideDelayMinSeconds,
            slideshowControlsHideDelayMaxSeconds,
          )
          .toInt(),
    );
    await _updateSetting(
      () => _updateSlideshowControlsHideDelayUseCase(clampedDelay),
      (settings) => settings.copyWith(slideshowControlsHideDelay: clampedDelay),
    );
  }

  /// Removes cache entries whose file or folder is gone from disk, keeping tags
  /// and favorites for everything still present. Returns how many entries were
  /// removed, or null when the operation failed outright.
  Future<int?> clearMediaCache() async {
    try {
      final removed = await _clearMediaCacheUseCase();
      await _tagCacheRefresher.refresh();
      return removed;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to clean media cache: $error');
      LoggingService.instance.debug('$stackTrace');
      return null;
    }
  }

  /// Re-reads every folder in the library from disk, picking up files added,
  /// changed, or removed outside the app. Tags survive for everything still
  /// present. Returns the number of folders rescanned, or null on failure.
  Future<int?> rescanLibrary({
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final folders = await _rescanLibraryUseCase(onProgress: onProgress);
      await _tagCacheRefresher.refresh();
      return folders;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to rescan library: $error');
      LoggingService.instance.debug('$stackTrace');
      return null;
    }
  }

  Future<bool> clearDirectoryCache() async {
    try {
      final directoryViewModel = ref.read(directoryViewModelProvider.notifier);
      await directoryViewModel.clearDirectories();
      return true;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to clear directory cache: $error');
      LoggingService.instance.debug('$stackTrace');
      return false;
    }
  }

  Future<bool> clearFavorites() async {
    try {
      final favoritesViewModel = ref.read(favoritesViewModelProvider.notifier);
      await favoritesViewModel.clearAllFavorites();
      return true;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to clear favorites: $error');
      LoggingService.instance.debug('$stackTrace');
      return false;
    }
  }

  Future<bool> clearTagAssignments() async {
    try {
      await _clearTagAssignmentsUseCase();
      return true;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to clear tag assignments: $error');
      LoggingService.instance.debug('$stackTrace');
      return false;
    }
  }

  Future<bool> clearTags() async {
    try {
      await _clearTagsUseCase();
      return true;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to clear tags: $error');
      LoggingService.instance.debug('$stackTrace');
      return false;
    }
  }

  /// Writes the active profile's tags and favorites into per-folder sidecar
  /// manifests. Returns null only on an unexpected top-level failure; ordinary
  /// per-folder write failures are reported inside the result.
  Future<SidecarExportResult?> exportSidecars({
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      return await _exportSidecarsUseCase(onProgress: onProgress);
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to export sidecars: $error');
      LoggingService.instance.debug('$stackTrace');
      return null;
    }
  }

  /// Reads sidecar manifests from disk and merges their tags and favorites into
  /// the active profile, then refreshes the tag and favorite caches so the UI
  /// reflects the imported data. Returns null on an unexpected failure.
  Future<SidecarImportResult?> importSidecars({
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final result = await _importSidecarsUseCase(onProgress: onProgress);
      await _tagCacheRefresher.refresh();
      await ref.read(favoritesViewModelProvider.notifier).loadFavorites();
      return result;
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to import sidecars: $error');
      LoggingService.instance.debug('$stackTrace');
      return null;
    }
  }

  Future<void> _updatePlayback(
    PlaybackSettings Function(PlaybackSettings) builder,
  ) async {
    await _updateSetting(
      () async {
        final current =
            state.valueOrNull?.playbackSettings ??
            const PlaybackSettings.initial();
        await _updatePlaybackSettingsUseCase(builder(current));
      },
      (settings) => settings.copyWith(
        playbackSettings: builder(settings.playbackSettings),
      ),
    );
  }

  Future<void> _updateSetting(
    Future<void> Function() persist,
    AppSettings Function(AppSettings) mapper,
  ) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final updatedSettings = mapper(current);
    state = AsyncValue.data(updatedSettings);

    final result = await AsyncValue.guard(persist);
    if (result.hasError) {
      LoggingService.instance.error(
        'Failed to persist settings change: ${result.error}',
      );
      state = AsyncValue.data(current);
    }
  }
}
