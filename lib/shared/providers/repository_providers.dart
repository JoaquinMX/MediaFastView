import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/services/file_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/isar_database.dart';
import '../../core/services/isar_schemas.dart';
import '../../features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../features/media_library/data/repositories/directory_repository_impl.dart';
import '../../features/media_library/data/repositories/file_operations_repository_impl.dart';
import '../../features/media_library/data/repositories/filesystem_media_repository_impl.dart';
import '../../features/media_library/data/isar/isar_directory_data_source.dart';
import '../../features/media_library/data/isar/isar_media_data_source.dart';
import '../../features/media_library/domain/repositories/directory_repository.dart';
import '../../features/media_library/domain/repositories/file_operations_repository.dart';
import '../../features/media_library/domain/repositories/media_repository.dart';
import '../../features/media_library/domain/use_cases/add_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/clear_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/delete_file_use_case.dart';
import '../../features/media_library/domain/use_cases/get_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/get_media_use_case.dart';
import '../../features/media_library/domain/use_cases/remove_directory_use_case.dart';
import '../../features/media_library/domain/use_cases/search_directories_use_case.dart';
import '../../features/media_library/domain/use_cases/validate_path_use_case.dart';
import '../../features/media_library/domain/use_cases/update_directory_access_use_case.dart';
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
import '../../features/media_library/data/repositories/tag_repository_impl.dart';
import '../../features/tagging/data/isar/isar_tag_data_source.dart';
import '../../features/media_library/domain/repositories/tag_repository.dart';
import '../../features/favorites/data/isar/isar_favorites_data_source.dart';

// Isar database provider
final isarDatabaseProvider = Provider<IsarDatabase>((ref) {
  final database = IsarDatabase(schemas: isarCollectionSchemas);
  ref.onDispose(database.close);
  unawaited(database.open());
  return database;
});

final isarDirectoryDataSourceProvider =
    Provider<IsarDirectoryDataSource>(
      (ref) => IsarDirectoryDataSource(ref.watch(isarDatabaseProvider)),
    );

final isarMediaDataSourceProvider = Provider<IsarMediaDataSource>(
  (ref) => IsarMediaDataSource(ref.watch(isarDatabaseProvider)),
);

// Local directory data source provider
final localDirectoryDataSourceProvider = Provider<LocalDirectoryDataSource>(
  (ref) => LocalDirectoryDataSource(
    bookmarkService: ref.watch(bookmarkServiceProvider),
  ),
);

final isarTagDataSourceProvider = Provider<IsarTagDataSource>(
  (ref) => IsarTagDataSource(ref.watch(isarDatabaseProvider)),
);

final isarFavoritesDataSourceProvider = Provider<IsarFavoritesDataSource>(
  (ref) => IsarFavoritesDataSource(ref.watch(isarDatabaseProvider)),
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
      (ref) {
        return DirectoryRepositoryNotifier(
          DirectoryRepositoryImpl(
            ref.watch(isarDirectoryDataSourceProvider),
            ref.watch(localDirectoryDataSourceProvider),
            ref.watch(bookmarkServiceProvider),
            ref.watch(permissionServiceProvider),
            ref.watch(isarMediaDataSourceProvider),
          ),
        );
      },
    );

final mediaRepositoryProvider =
    StateNotifierProvider.autoDispose<MediaRepositoryNotifier, MediaRepository>(
      (ref) {
        return MediaRepositoryNotifier(
          FilesystemMediaRepositoryImpl(
            ref.watch(bookmarkServiceProvider),
            ref.watch(directoryRepositoryProvider),
            ref.watch(isarMediaDataSourceProvider),
            permissionService: ref.watch(permissionServiceProvider),
          ),
        );
      },
    );

final tagRepositoryProvider =
    StateNotifierProvider.autoDispose<TagRepositoryNotifier, TagRepository>(
      (ref) {
        return TagRepositoryNotifier(
          TagRepositoryImpl(ref.watch(isarTagDataSourceProvider)),
        );
      },
    );

final favoritesRepositoryProvider =
    StateNotifierProvider.autoDispose<
      FavoritesRepositoryNotifier,
      FavoritesRepository
    >(
      (ref) {
        return FavoritesRepositoryNotifier(
          FavoritesRepositoryImpl(ref.watch(isarFavoritesDataSourceProvider)),
        );
      },
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
  );
});

final updateDirectoryAccessUseCaseProvider =
    Provider<UpdateDirectoryAccessUseCase>((ref) {
  return UpdateDirectoryAccessUseCase(ref.watch(directoryRepositoryProvider));
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
    return LoadMediaForViewingUseCase(ref.watch(isarMediaDataSourceProvider));
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

final directoryPreviewStripProvider =
    FutureProvider.family<List<String>, String>((ref, directoryPath) async {
  debugPrint('Getting directory preview strip for: $directoryPath');
  final fileService = ref.watch(fileServiceProvider);
  try {
    final contents = await fileService.getDirectoryContents(directoryPath);
    final imageFiles = contents
        .whereType<File>()
        .where(
          (entity) =>
              fileService.getMediaTypeFromExtension(entity.path) == 'image',
        )
        .take(5)
        .map((entity) => entity.path)
        .toList();
    return imageFiles;
  } catch (e) {
    debugPrint('Error getting preview strip for $directoryPath: $e');
  }
  return const <String>[];
});
