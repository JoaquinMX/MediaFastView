import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/services/file_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/isar_database.dart';
import '../../core/services/isar_key_migration.dart';
import '../../core/services/isar_profile_migration.dart';
import '../../core/services/isar_schemas.dart';
import 'active_profile_provider.dart';
import '../../features/media_library/data/data_sources/filesystem_media_data_source.dart';
import '../../features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../features/media_library/data/isar/isar_directory_cover_data_source.dart';
import '../../features/media_library/data/repositories/directory_repository_impl.dart';
import '../../features/media_library/data/repositories/directory_cover_repository_impl.dart';
import '../../features/media_library/data/repositories/file_operations_repository_impl.dart';
import '../../features/media_library/data/repositories/filesystem_media_repository_impl.dart';
import '../../features/media_library/data/isar/isar_directory_data_source.dart';
import '../../features/media_library/data/isar/isar_media_data_source.dart';
import '../../features/media_library/domain/entities/directory_media_counts.dart';
import '../../features/media_library/domain/entities/directory_cover_entity.dart';
import '../../features/media_library/domain/repositories/directory_repository.dart';
import '../../features/media_library/domain/repositories/directory_cover_repository.dart';
import '../../features/media_library/domain/repositories/file_operations_repository.dart';
import '../../features/media_library/domain/repositories/media_repository.dart';
import '../../features/media_library/domain/use_cases/add_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/clear_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_file_use_case.dart';
import '../../features/media_library/domain/use_cases/clear_media_cache_use_case.dart';
import '../../features/media_library/domain/use_cases/rescan_library_use_case.dart';
import '../../features/media_library/domain/use_cases/get_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/get_media_use_case.dart';
import '../../features/media_library/domain/use_cases/remove_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/reconcile_directory_cover_use_case.dart';
import '../../features/media_library/domain/use_cases/reset_directory_cover_use_case.dart';
import '../../features/media_library/domain/use_cases/search_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/set_directory_cover_use_case.dart';
import '../../features/media_library/domain/use_cases/set_directory_no_cover_use_case.dart';
import '../../features/media_library/domain/entities/directory_entity.dart';
import '../../features/media_library/domain/use_cases/reconcile_transferred_media_use_case.dart';
import '../../features/media_library/domain/use_cases/transfer_media_use_case.dart';
import '../../features/media_library/domain/use_cases/validate_path_use_case.dart';
import '../../features/media_library/domain/use_cases/update_directory_access_use_case.dart';
import '../../features/tagging/domain/use_cases/get_tags_use_case.dart';
import '../../features/tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../features/tagging/data/isar/isar_saved_filter_data_source.dart';
import '../../features/tagging/data/repositories/saved_filter_repository_impl.dart';
import '../../features/tagging/domain/entities/saved_filter_entity.dart';
import '../../features/tagging/domain/entities/tag_usage.dart';
import '../../features/tagging/domain/repositories/saved_filter_repository.dart';
import '../../features/tagging/domain/use_cases/create_tag_use_case.dart';
import '../../features/tagging/domain/use_cases/delete_saved_filter_use_case.dart';
import '../../features/tagging/domain/use_cases/delete_tag_use_case.dart';
import '../../features/tagging/domain/use_cases/get_saved_filters_use_case.dart';
import '../../features/tagging/domain/use_cases/save_filter_use_case.dart';
import '../../features/tagging/domain/use_cases/get_tag_usage_use_case.dart';
import '../../features/tagging/domain/use_cases/merge_tags_use_case.dart';
import '../../features/tagging/domain/use_cases/update_tag_use_case.dart';
import '../../features/tagging/domain/use_cases/filter_by_tags_use_case.dart';
import '../../features/tagging/domain/use_cases/clear_tag_assignments_use_case.dart';
import '../../features/tagging/domain/use_cases/clear_tags_use_case.dart';
import '../../features/favorites/domain/use_cases/get_favorites_use_case.dart';
import '../../features/favorites/domain/use_cases/favorite_media_use_case.dart';
import '../../features/favorites/domain/use_cases/toggle_favorite_use_case.dart';
import '../../features/favorites/domain/use_cases/start_slideshow_use_case.dart';
import '../../features/full_screen/data/repositories/media_viewer_repository_impl.dart';
import '../../features/full_screen/domain/repositories/media_viewer_repository.dart';
import '../../features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import '../../features/media_library/data/repositories/tag_repository_impl.dart';
import '../../features/tagging/data/isar/isar_tag_data_source.dart';
import '../../features/media_library/domain/repositories/tag_repository.dart';
import '../../features/favorites/data/isar/isar_favorites_data_source.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/use_cases/get_app_settings_use_case.dart';
import '../../features/settings/domain/use_cases/update_auto_navigate_sibling_directories_use_case.dart';
import '../../features/settings/domain/use_cases/update_delete_from_source_use_case.dart';
import '../../features/settings/domain/use_cases/update_navigate_to_sibling_after_directory_delete_use_case.dart';
import '../../features/settings/domain/use_cases/update_playback_settings_use_case.dart';
import '../../features/settings/domain/use_cases/update_show_directory_tagged_media_counts_use_case.dart';
import '../../features/settings/domain/use_cases/update_slideshow_controls_hide_delay_use_case.dart';
import '../../features/settings/domain/use_cases/update_theme_mode_use_case.dart';
import '../../features/settings/domain/use_cases/update_thumbnail_disk_cache_use_case.dart';
import '../utils/tag_lookup.dart';

/// Every migration the database needs, in the order it needs them.
///
/// Shared with `main`, which builds its own [IsarDatabase] to bootstrap the
/// active profile before the first frame and then overrides
/// [isarDatabaseProvider] with it — so both paths agree on how the database is
/// brought up to date.
///
/// The key migration runs first: it moves favorites off the legacy byte-sum id,
/// and the profile migration then re-keys them again onto the profile-scoped key.
/// Both are self-detecting, so a database that needs neither pays nothing and a
/// database that needs both converges in one launch.
Future<void> runIsarMigrations(
  Isar isar,
  Future<void> Function() backUp,
) async {
  await const IsarKeyMigration().run(isar, backUp: backUp);
  await const IsarProfileMigration().run(isar, backUp: backUp);
}

// Isar database provider
final isarDatabaseProvider = Provider<IsarDatabase>((ref) {
  final database = IsarDatabase(
    schemas: isarCollectionSchemas,
    // Runs before the instance is published, so no data source can read or write
    // against rows that are about to be re-keyed.
    migrate: runIsarMigrations,
  );
  ref.onDispose(database.close);
  unawaited(database.open());
  return database;
});

final isarDirectoryDataSourceProvider = Provider<IsarDirectoryDataSource>(
  (ref) => IsarDirectoryDataSource(
    ref.watch(isarDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider),
  ),
);

final isarMediaDataSourceProvider = Provider<IsarMediaDataSource>(
  (ref) => IsarMediaDataSource(
    ref.watch(isarDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider),
  ),
);

final isarDirectoryCoverDataSourceProvider =
    Provider<IsarDirectoryCoverDataSource>(
      (ref) => IsarDirectoryCoverDataSource(
        ref.watch(isarDatabaseProvider),
        profileId: ref.watch(activeProfileIdProvider),
      ),
    );

final filesystemMediaDataSourceProvider = Provider<FilesystemMediaDataSource>(
  (ref) => FilesystemMediaDataSource(
    ref.watch(bookmarkServiceProvider),
    ref.watch(permissionServiceProvider),
  ),
);

// Local directory data source provider
final localDirectoryDataSourceProvider = Provider<LocalDirectoryDataSource>(
  (ref) => LocalDirectoryDataSource(
    bookmarkService: ref.watch(bookmarkServiceProvider),
  ),
);

final isarTagDataSourceProvider = Provider<IsarTagDataSource>(
  (ref) => IsarTagDataSource(
    ref.watch(isarDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider),
  ),
);

final isarSavedFilterDataSourceProvider = Provider<IsarSavedFilterDataSource>(
  (ref) => IsarSavedFilterDataSource(
    ref.watch(isarDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider),
  ),
);

final isarFavoritesDataSourceProvider = Provider<IsarFavoritesDataSource>(
  (ref) => IsarFavoritesDataSource(
    ref.watch(isarDatabaseProvider),
    profileId: ref.watch(activeProfileIdProvider),
  ),
);

// Service providers
final bookmarkServiceProvider = Provider<BookmarkService>(
  (ref) => BookmarkService.instance,
);

final fileServiceProvider = Provider<FileService>((ref) => FileService());

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.watch(bookmarkServiceProvider)),
);

// Repository providers with auto-dispose
final directoryRepositoryProvider =
    StateNotifierProvider.autoDispose<
      DirectoryRepositoryNotifier,
      DirectoryRepository
    >((ref) {
      return DirectoryRepositoryNotifier(
        DirectoryRepositoryImpl(
          ref.watch(isarDirectoryDataSourceProvider),
          ref.watch(localDirectoryDataSourceProvider),
          ref.watch(bookmarkServiceProvider),
          ref.watch(permissionServiceProvider),
          ref.watch(isarMediaDataSourceProvider),
          ref.watch(filesystemMediaDataSourceProvider),
        ),
      );
    });

final mediaRepositoryProvider =
    StateNotifierProvider.autoDispose<MediaRepositoryNotifier, MediaRepository>(
      (ref) {
        return MediaRepositoryNotifier(
          FilesystemMediaRepositoryImpl(
            ref.watch(bookmarkServiceProvider),
            ref.watch(directoryRepositoryProvider),
            ref.watch(isarMediaDataSourceProvider),
            permissionService: ref.watch(permissionServiceProvider),
            filesystemDataSource: ref.watch(filesystemMediaDataSourceProvider),
          ),
        );
      },
    );

/// Changes whenever the active profile's directory-cover records are mutated.
final directoryCoverRevisionProvider = StateProvider<int>((ref) => 0);

final directoryCoverRepositoryProvider = Provider<DirectoryCoverRepository>((
  ref,
) {
  return _NotifyingDirectoryCoverRepository(
    _DeferredDirectoryCoverRepository(
      () => DirectoryCoverRepositoryImpl(
        ref.read(isarDirectoryCoverDataSourceProvider),
      ),
    ),
    () {
      ref.read(directoryCoverRevisionProvider.notifier).state += 1;
    },
  );
});

final directoryMediaCountsProvider =
    FutureProvider.autoDispose<Map<String, DirectoryMediaCounts>>((ref) async {
      return ref.watch(mediaRepositoryProvider).getDirectoryMediaCounts();
    });

final tagRepositoryProvider =
    StateNotifierProvider.autoDispose<TagRepositoryNotifier, TagRepository>((
      ref,
    ) {
      return TagRepositoryNotifier(
        TagRepositoryImpl(ref.watch(isarTagDataSourceProvider)),
      );
    });

final savedFilterRepositoryProvider =
    StateNotifierProvider.autoDispose<
      SavedFilterRepositoryNotifier,
      SavedFilterRepository
    >((ref) {
      return SavedFilterRepositoryNotifier(
        SavedFilterRepositoryImpl(ref.watch(isarSavedFilterDataSourceProvider)),
      );
    });

final tagLookupProvider = Provider<TagLookup>((ref) {
  return TagLookup(ref.watch(tagRepositoryProvider));
});

final favoritesRepositoryProvider =
    StateNotifierProvider.autoDispose<
      FavoritesRepositoryNotifier,
      FavoritesRepository
    >((ref) {
      return FavoritesRepositoryNotifier(
        FavoritesRepositoryImpl(ref.watch(isarFavoritesDataSourceProvider)),
      );
    });

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SettingsRepositoryImpl();
});

final fileOperationsRepositoryProvider = Provider<FileOperationsRepository>((
  ref,
) {
  return FileOperationsRepositoryImpl(
    ref.watch(fileServiceProvider),
    ref.watch(permissionServiceProvider),
    ref.watch(bookmarkServiceProvider),
  );
});

// Notifiers for repository StateNotifierProviders
class DirectoryRepositoryNotifier extends StateNotifier<DirectoryRepository> {
  DirectoryRepositoryNotifier(DirectoryRepository repository)
    : super(repository);
}

class MediaRepositoryNotifier extends StateNotifier<MediaRepository> {
  MediaRepositoryNotifier(MediaRepository repository) : super(repository);
}

class TagRepositoryNotifier extends StateNotifier<TagRepository> {
  TagRepositoryNotifier(TagRepository repository) : super(repository);
}

class SavedFilterRepositoryNotifier
    extends StateNotifier<SavedFilterRepository> {
  SavedFilterRepositoryNotifier(SavedFilterRepository repository)
    : super(repository);
}

class FavoritesRepositoryNotifier extends StateNotifier<FavoritesRepository> {
  FavoritesRepositoryNotifier(FavoritesRepository repository)
    : super(repository);
}

class _NotifyingDirectoryCoverRepository implements DirectoryCoverRepository {
  const _NotifyingDirectoryCoverRepository(this._delegate, this._onChanged);

  final DirectoryCoverRepository _delegate;
  final void Function() _onChanged;

  @override
  Future<void> clearCovers() {
    return _mutate(_delegate.clearCovers);
  }

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) {
    return _delegate.getCover(directoryPath);
  }

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) {
    return _mutate(
      () => _delegate.rebaseDirectoryTree(
        oldRootPath: oldRootPath,
        newRootPath: newRootPath,
      ),
    );
  }

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) {
    return _mutate(
      () => _delegate.reconcileMediaMove(oldPath: oldPath, newPath: newPath),
    );
  }

  @override
  Future<void> removeCover(String directoryPath) {
    return _mutate(() => _delegate.removeCover(directoryPath));
  }

  @override
  Future<void> removeCoverForSource(String sourcePath) {
    return _mutate(() => _delegate.removeCoverForSource(sourcePath));
  }

  @override
  Future<void> removeCoversUnder(String directoryPath) {
    return _mutate(() => _delegate.removeCoversUnder(directoryPath));
  }

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) {
    return _mutate(() => _delegate.saveCover(cover));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    _onChanged();
  }
}

class _DeferredDirectoryCoverRepository implements DirectoryCoverRepository {
  const _DeferredDirectoryCoverRepository(this._resolve);

  final DirectoryCoverRepository Function() _resolve;

  @override
  Future<void> clearCovers() => _resolve().clearCovers();

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) {
    return _resolve().getCover(directoryPath);
  }

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) {
    return _resolve().rebaseDirectoryTree(
      oldRootPath: oldRootPath,
      newRootPath: newRootPath,
    );
  }

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) {
    return _resolve().reconcileMediaMove(oldPath: oldPath, newPath: newPath);
  }

  @override
  Future<void> removeCover(String directoryPath) {
    return _resolve().removeCover(directoryPath);
  }

  @override
  Future<void> removeCoverForSource(String sourcePath) {
    return _resolve().removeCoverForSource(sourcePath);
  }

  @override
  Future<void> removeCoversUnder(String directoryPath) {
    return _resolve().removeCoversUnder(directoryPath);
  }

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) {
    return _resolve().saveCover(cover);
  }
}

// Use case providers
final getDirectoriesUseCaseProvider = Provider<GetDirectoriesUseCase>((ref) {
  return GetDirectoriesUseCase(ref.watch(directoryRepositoryProvider));
});

final getMediaUseCaseProvider = Provider<GetMediaUseCase>((ref) {
  return GetMediaUseCase(ref.watch(mediaRepositoryProvider));
});

final searchDirectoriesUseCaseProvider = Provider<SearchDirectoriesUseCase>((
  ref,
) {
  return const SearchDirectoriesUseCase();
});

final addDirectoryUseCaseProvider = Provider<AddDirectoryUseCase>((ref) {
  return AddDirectoryUseCase(ref.watch(directoryRepositoryProvider));
});

final removeDirectoryUseCaseProvider = Provider<RemoveDirectoryUseCase>((ref) {
  return RemoveDirectoryUseCase(
    ref.watch(directoryRepositoryProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(favoritesRepositoryProvider),
    ref.watch(directoryCoverRepositoryProvider),
  );
});

final updateDirectoryAccessUseCaseProvider =
    Provider<UpdateDirectoryAccessUseCase>((ref) {
      return UpdateDirectoryAccessUseCase(
        ref.watch(directoryRepositoryProvider),
      );
    });

final clearDirectoriesUseCaseProvider = Provider<ClearDirectoriesUseCase>((
  ref,
) {
  return ClearDirectoriesUseCase(
    ref.watch(directoryRepositoryProvider),
    ref.watch(directoryCoverRepositoryProvider),
  );
});

final clearMediaCacheUseCaseProvider = Provider<ClearMediaCacheUseCase>((ref) {
  return ClearMediaCacheUseCase(ref.watch(mediaRepositoryProvider));
});

final rescanLibraryUseCaseProvider = Provider<RescanLibraryUseCase>((ref) {
  return RescanLibraryUseCase(ref.watch(mediaRepositoryProvider));
});

final deleteFileUseCaseProvider = Provider<DeleteFileUseCase>((ref) {
  return DeleteFileUseCase(
    ref.watch(fileOperationsRepositoryProvider),
    directoryCoverRepository: ref.watch(directoryCoverRepositoryProvider),
  );
});

final deleteDirectoryUseCaseProvider = Provider<DeleteDirectoryUseCase>((ref) {
  return DeleteDirectoryUseCase(
    ref.watch(fileOperationsRepositoryProvider),
    directoryCoverRepository: ref.watch(directoryCoverRepositoryProvider),
  );
});

final validatePathUseCaseProvider = Provider<ValidatePathUseCase>((ref) {
  return ValidatePathUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final moveMediaUseCaseProvider = Provider<MoveMediaUseCase>((ref) {
  return MoveMediaUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final copyMediaUseCaseProvider = Provider<CopyMediaUseCase>((ref) {
  return CopyMediaUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final reconcileTransferredMediaUseCaseProvider =
    Provider<ReconcileTransferredMediaUseCase>((ref) {
      return ReconcileTransferredMediaUseCase(
        ref.watch(isarMediaDataSourceProvider),
        ref.watch(favoritesRepositoryProvider),
        ref.watch(directoryRepositoryProvider),
        ref.watch(bookmarkServiceProvider),
        directoryCoverRepository: ref.watch(directoryCoverRepositoryProvider),
      );
    });

final setDirectoryCoverUseCaseProvider = Provider<SetDirectoryCoverUseCase>((
  ref,
) {
  return SetDirectoryCoverUseCase(ref.watch(directoryCoverRepositoryProvider));
});

final reconcileDirectoryCoverUseCaseProvider =
    Provider<ReconcileDirectoryCoverUseCase>((ref) {
      return ReconcileDirectoryCoverUseCase(
        ref.watch(directoryCoverRepositoryProvider),
      );
    });

final setDirectoryNoCoverUseCaseProvider = Provider<SetDirectoryNoCoverUseCase>(
  (ref) {
    return SetDirectoryNoCoverUseCase(
      ref.watch(directoryCoverRepositoryProvider),
    );
  },
);

final resetDirectoryCoverUseCaseProvider = Provider<ResetDirectoryCoverUseCase>(
  (ref) {
    return ResetDirectoryCoverUseCase(
      ref.watch(directoryCoverRepositoryProvider),
    );
  },
);

/// The tracked library roots.
///
/// A plain list, for callers such as the destination picker that only need to
/// know which folders exist — as opposed to [directoryViewModelProvider], which
/// drives the library grid and does accessibility scanning along the way.
final trackedDirectoriesProvider =
    FutureProvider.autoDispose<List<DirectoryEntity>>((ref) {
      return ref.watch(directoryRepositoryProvider).getDirectories();
    });

/// Identifies a directory to list subdirectories for, along with the bookmark
/// that grants access to it.
class SubdirectoryQuery {
  const SubdirectoryQuery({required this.path, this.bookmarkData});

  final String path;
  final String? bookmarkData;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubdirectoryQuery &&
          path == other.path &&
          bookmarkData == other.bookmarkData;

  @override
  int get hashCode => Object.hash(path, bookmarkData);
}

/// Lists the subdirectories of a directory, holding security-scoped access for
/// the duration of the scan.
///
/// The scope matters: [FilesystemMediaDataSource.scanSubdirectories] swallows
/// access failures and returns an empty list, so without it a sandboxed build
/// would silently show every folder as having no children.
final subdirectoriesProvider = FutureProvider.autoDispose
    .family<List<String>, SubdirectoryQuery>((ref, query) async {
      final bookmarkService = ref.watch(bookmarkServiceProvider);
      final dataSource = ref.watch(filesystemMediaDataSourceProvider);

      final bookmarkData = query.bookmarkData;
      var scoped = false;
      if (bookmarkData != null) {
        try {
          await bookmarkService.startAccessingBookmark(bookmarkData);
          scoped = true;
        } catch (e) {
          debugPrint('Could not open scope for ${query.path}: $e');
        }
      }

      try {
        return await dataSource.scanSubdirectories(query.path);
      } finally {
        if (scoped) {
          await bookmarkService.stopAccessingBookmark(bookmarkData!);
        }
      }
    });

// Settings use case providers
final getAppSettingsUseCaseProvider = Provider<GetAppSettingsUseCase>((ref) {
  return GetAppSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

final updateThemeModeUseCaseProvider = Provider<UpdateThemeModeUseCase>((ref) {
  return UpdateThemeModeUseCase(ref.watch(settingsRepositoryProvider));
});

final updateThumbnailDiskCacheUseCaseProvider =
    Provider<UpdateThumbnailDiskCacheUseCase>((ref) {
      return UpdateThumbnailDiskCacheUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updateDeleteFromSourceUseCaseProvider =
    Provider<UpdateDeleteFromSourceUseCase>((ref) {
      return UpdateDeleteFromSourceUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updatePlaybackSettingsUseCaseProvider =
    Provider<UpdatePlaybackSettingsUseCase>((ref) {
      return UpdatePlaybackSettingsUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updateAutoNavigateSiblingDirectoriesUseCaseProvider =
    Provider<UpdateAutoNavigateSiblingDirectoriesUseCase>((ref) {
      return UpdateAutoNavigateSiblingDirectoriesUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updateNavigateToSiblingAfterDirectoryDeleteUseCaseProvider =
    Provider<UpdateNavigateToSiblingAfterDirectoryDeleteUseCase>((ref) {
      return UpdateNavigateToSiblingAfterDirectoryDeleteUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updateShowDirectoryTaggedMediaCountsUseCaseProvider =
    Provider<UpdateShowDirectoryTaggedMediaCountsUseCase>((ref) {
      return UpdateShowDirectoryTaggedMediaCountsUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });

final updateSlideshowControlsHideDelayUseCaseProvider =
    Provider<UpdateSlideshowControlsHideDelayUseCase>((ref) {
      return UpdateSlideshowControlsHideDelayUseCase(
        ref.watch(settingsRepositoryProvider),
      );
    });
// Tag use case providers
final getTagsUseCaseProvider = Provider<GetTagsUseCase>((ref) {
  return GetTagsUseCase(ref.watch(tagRepositoryProvider));
});

final createTagUseCaseProvider = Provider<CreateTagUseCase>((ref) {
  return CreateTagUseCase(ref.watch(tagRepositoryProvider));
});

final updateTagUseCaseProvider = Provider<UpdateTagUseCase>((ref) {
  return UpdateTagUseCase(ref.watch(tagRepositoryProvider));
});

final mergeTagsUseCaseProvider = Provider<MergeTagsUseCase>((ref) {
  return MergeTagsUseCase(
    tagRepository: ref.watch(tagRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    directoryRepository: ref.watch(directoryRepositoryProvider),
    savedFilterRepository: ref.watch(savedFilterRepositoryProvider),
  );
});

final deleteTagUseCaseProvider = Provider<DeleteTagUseCase>((ref) {
  return DeleteTagUseCase(
    tagRepository: ref.watch(tagRepositoryProvider),
    savedFilterRepository: ref.watch(savedFilterRepositoryProvider),
  );
});

// Saved filter use case providers
final getSavedFiltersUseCaseProvider = Provider<GetSavedFiltersUseCase>((ref) {
  return GetSavedFiltersUseCase(ref.watch(savedFilterRepositoryProvider));
});

final saveFilterUseCaseProvider = Provider<SaveFilterUseCase>((ref) {
  return SaveFilterUseCase(ref.watch(savedFilterRepositoryProvider));
});

final deleteSavedFilterUseCaseProvider = Provider<DeleteSavedFilterUseCase>((
  ref,
) {
  return DeleteSavedFilterUseCase(ref.watch(savedFilterRepositoryProvider));
});

/// Every saved filter, oldest first. Invalidated whenever one is written.
final savedFiltersProvider =
    FutureProvider.autoDispose<List<SavedFilterEntity>>(
      (ref) => ref.watch(getSavedFiltersUseCaseProvider)(),
    );

final getTagUsageUseCaseProvider = Provider<GetTagUsageUseCase>((ref) {
  return GetTagUsageUseCase(
    tagRepository: ref.watch(tagRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    directoryRepository: ref.watch(directoryRepositoryProvider),
  );
});

/// How many files and folders carry each tag, keyed by tag id.
///
/// Invalidated by [TagCacheRefresher], so counts follow every tag mutation.
final tagUsageProvider = FutureProvider.autoDispose<Map<String, TagUsage>>(
  (ref) => ref.watch(getTagUsageUseCaseProvider)(),
);

final clearTagAssignmentsUseCaseProvider = Provider<ClearTagAssignmentsUseCase>(
  (ref) {
    return ClearTagAssignmentsUseCase(
      directoryRepository: ref.watch(directoryRepositoryProvider),
      mediaRepository: ref.watch(mediaRepositoryProvider),
    );
  },
);

final clearTagsUseCaseProvider = Provider<ClearTagsUseCase>((ref) {
  return ClearTagsUseCase(
    tagRepository: ref.watch(tagRepositoryProvider),
    clearTagAssignmentsUseCase: ref.watch(clearTagAssignmentsUseCaseProvider),
  );
});

final assignTagUseCaseProvider = Provider<AssignTagUseCase>((ref) {
  return AssignTagUseCase(
    directoryRepository: ref.watch(directoryRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
  );
});

final filterByTagsUseCaseProvider = Provider<FilterByTagsUseCase>((ref) {
  return FilterByTagsUseCase(
    directoryRepository: ref.watch(directoryRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
  );
});

// Favorites use case providers
final favoriteMediaUseCaseProvider = Provider<FavoriteMediaUseCase>((ref) {
  return FavoriteMediaUseCase(
    ref.watch(mediaRepositoryProvider),
    ref.watch(getMediaUseCaseProvider),
  );
});

final getFavoritesUseCaseProvider = Provider<GetFavoritesUseCase>((ref) {
  return GetFavoritesUseCase(ref.watch(favoritesRepositoryProvider));
});

final toggleFavoriteUseCaseProvider = Provider<ToggleFavoriteUseCase>((ref) {
  return ToggleFavoriteUseCase(ref.watch(favoritesRepositoryProvider));
});

final startSlideshowUseCaseProvider = Provider<StartSlideshowUseCase>((ref) {
  return const StartSlideshowUseCase();
});

// Full-screen providers
final mediaViewerRepositoryProvider =
    StateNotifierProvider.autoDispose<
      MediaViewerRepositoryNotifier,
      MediaViewerRepository
    >(
      (ref) => MediaViewerRepositoryNotifier(
        MediaViewerRepositoryImpl(ref.watch(mediaRepositoryProvider)),
      ),
    );

class MediaViewerRepositoryNotifier
    extends StateNotifier<MediaViewerRepository> {
  MediaViewerRepositoryNotifier(MediaViewerRepository repository)
    : super(repository);
}

final loadMediaForViewingUseCaseProvider = Provider<LoadMediaForViewingUseCase>(
  (ref) {
    return LoadMediaForViewingUseCase(ref.watch(isarMediaDataSourceProvider));
  },
);
