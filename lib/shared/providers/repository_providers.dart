import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/favorites/data/data_sources/shared_preferences_data_source.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/services/file_service.dart';
import '../../core/services/permission_service.dart';
import '../../features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../features/media_library/data/data_sources/local_media_data_source.dart';
import '../../features/media_library/data/data_sources/shared_preferences_data_source.dart';
import '../../features/media_library/data/repositories/directory_repository_impl.dart';
import '../../features/media_library/data/repositories/file_operations_repository_impl.dart';
import '../../features/media_library/data/repositories/filesystem_media_repository_impl.dart';
import '../../features/media_library/domain/repositories/directory_repository.dart';
import '../../features/media_library/domain/repositories/file_operations_repository.dart';
import '../../features/media_library/domain/repositories/media_repository.dart';
import '../../features/media_library/domain/use_cases/add_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/bulk_rename_use_case.dart';
import '../../features/media_library/domain/use_cases/clear_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_file_use_case.dart';
import '../../features/media_library/domain/use_cases/get_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/move_to_folder_use_case.dart';
import '../../features/media_library/domain/use_cases/move_to_trash_use_case.dart';
import '../../features/media_library/domain/use_cases/remove_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/restore_from_trash_use_case.dart';
import '../../features/media_library/domain/use_cases/search_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/validate_path_use_case.dart';
import '../../features/tagging/domain/use_cases/get_tags_use_case.dart';
import '../../features/tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../features/tagging/domain/use_cases/create_tag_use_case.dart';
import '../../features/tagging/domain/use_cases/filter_by_tags_use_case.dart';
import '../../features/favorites/domain/use_cases/get_favorites_use_case.dart';
import '../../features/favorites/domain/use_cases/toggle_favorite_use_case.dart';
import '../../features/favorites/domain/use_cases/start_slideshow_use_case.dart';
import '../../features/full_screen/data/repositories/media_viewer_repository_impl.dart';
import '../../features/full_screen/domain/repositories/media_viewer_repository.dart';
import '../../features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import '../../features/tagging/data/data_sources/shared_preferences_data_source.dart';
import '../../features/tagging/data/repositories/tag_repository_impl.dart';
import '../../features/tagging/domain/repositories/tag_repository.dart';

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main');
});

// Directory data source provider
final directoryDataSourceProvider =
    Provider<SharedPreferencesDirectoryDataSource>(
      (ref) => SharedPreferencesDirectoryDataSource(
        ref.watch(sharedPreferencesProvider),
      ),
    );

// Media data source provider
final mediaDataSourceProvider = Provider<SharedPreferencesMediaDataSource>(
  (ref) =>
      SharedPreferencesMediaDataSource(ref.watch(sharedPreferencesProvider)),
);

// Local directory data source provider
final localDirectoryDataSourceProvider = Provider<LocalDirectoryDataSource>(
  (ref) => LocalDirectoryDataSource(
    bookmarkService: ref.watch(bookmarkServiceProvider),
  ),
);

// Tag data source provider
final tagDataSourceProvider = Provider<SharedPreferencesTagDataSource>(
  (ref) => SharedPreferencesTagDataSource(ref.watch(sharedPreferencesProvider)),
);

// Favorites data source provider
final favoritesDataSourceProvider =
    Provider<SharedPreferencesFavoritesDataSource>(
      (ref) => SharedPreferencesFavoritesDataSource(
        ref.watch(sharedPreferencesProvider),
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
    >(
      (ref) => DirectoryRepositoryNotifier(
        DirectoryRepositoryImpl(
          ref.watch(directoryDataSourceProvider),
          ref.watch(localDirectoryDataSourceProvider),
          ref.watch(bookmarkServiceProvider),
          ref.watch(permissionServiceProvider),
          ref.watch(mediaDataSourceProvider),
        ),
      ),
    );

final mediaRepositoryProvider =
    StateNotifierProvider.autoDispose<MediaRepositoryNotifier, MediaRepository>(
      (ref) => MediaRepositoryNotifier(
        FilesystemMediaRepositoryImpl(
          ref.watch(bookmarkServiceProvider),
          ref.watch(directoryRepositoryProvider),
          ref.watch(mediaDataSourceProvider),
          permissionService: ref.watch(permissionServiceProvider),
        ),
      ),
    );

final tagRepositoryProvider =
    StateNotifierProvider.autoDispose<TagRepositoryNotifier, TagRepository>(
      (ref) => TagRepositoryNotifier(
        TagRepositoryImpl(ref.watch(tagDataSourceProvider)),
      ),
    );

final favoritesRepositoryProvider =
    StateNotifierProvider.autoDispose<
      FavoritesRepositoryNotifier,
      FavoritesRepository
    >(
      (ref) => FavoritesRepositoryNotifier(
        FavoritesRepositoryImpl(ref.watch(favoritesDataSourceProvider)),
      ),
    );

final fileOperationsRepositoryProvider = Provider<FileOperationsRepository>((
  ref,
) {
  return FileOperationsRepositoryImpl(
    ref.watch(fileServiceProvider),
    ref.watch(permissionServiceProvider),
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

class FavoritesRepositoryNotifier extends StateNotifier<FavoritesRepository> {
  FavoritesRepositoryNotifier(FavoritesRepository repository)
    : super(repository);
}

// Use case providers
final getDirectoriesUseCaseProvider = Provider<GetDirectoriesUseCase>((ref) {
  return GetDirectoriesUseCase(ref.watch(directoryRepositoryProvider));
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
  );
});

final clearDirectoriesUseCaseProvider = Provider<ClearDirectoriesUseCase>((ref) {
  return ClearDirectoriesUseCase(ref.watch(directoryRepositoryProvider));
});

final deleteFileUseCaseProvider = Provider<DeleteFileUseCase>((ref) {
  return DeleteFileUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final deleteDirectoryUseCaseProvider = Provider<DeleteDirectoryUseCase>((ref) {
  return DeleteDirectoryUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final validatePathUseCaseProvider = Provider<ValidatePathUseCase>((ref) {
  return ValidatePathUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final bulkRenameUseCaseProvider = Provider<BulkRenameUseCase>((ref) {
  return BulkRenameUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final moveToFolderUseCaseProvider = Provider<MoveToFolderUseCase>((ref) {
  return MoveToFolderUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final moveToTrashUseCaseProvider = Provider<MoveToTrashUseCase>((ref) {
  return MoveToTrashUseCase(ref.watch(fileOperationsRepositoryProvider));
});

final restoreFromTrashUseCaseProvider =
    Provider<RestoreFromTrashUseCase>((ref) {
  return RestoreFromTrashUseCase(ref.watch(fileOperationsRepositoryProvider));
});
// Tag use case providers
final getTagsUseCaseProvider = Provider<GetTagsUseCase>((ref) {
  return GetTagsUseCase(ref.watch(tagRepositoryProvider));
});

final createTagUseCaseProvider = Provider<CreateTagUseCase>((ref) {
  return CreateTagUseCase(ref.watch(tagRepositoryProvider));
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
    return LoadMediaForViewingUseCase(ref.watch(mediaDataSourceProvider));
  },
);

// Directory preview provider
final directoryPreviewProvider = FutureProvider.family<String?, String>((
  ref,
  directoryPath,
) async {
  debugPrint('Getting directory preview for: $directoryPath');
  final fileService = ref.watch(fileServiceProvider);
  try {
    final contents = await fileService.getDirectoryContents(directoryPath);
    final imageFiles = contents.where((entity) {
      return entity is File &&
          fileService.getMediaTypeFromExtension(entity.path) == 'image';
    }).toList();
    debugPrint('Found ${imageFiles.length} image files in $directoryPath');
    if (imageFiles.isNotEmpty) {
      return imageFiles.first.path;
    }
  } catch (e) {
    debugPrint('Error getting directory contents for $directoryPath: $e');
  }
  return null;
});
