import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../media_library/data/data_sources/filesystem_media_data_source.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../media_library/domain/entities/media_entity.dart';

typedef FilesystemMediaDataSourceFactory = FilesystemMediaDataSource Function(
  BookmarkService bookmarkService,
  PermissionService permissionService,
);

/// Use case for loading media for full-screen viewing
class LoadMediaForViewingUseCase {
  LoadMediaForViewingUseCase(
    this._mediaDataSource, {
    FilesystemMediaDataSourceFactory? filesystemDataSourceFactory,
  }) : _filesystemDataSourceFactory =
            filesystemDataSourceFactory ?? _defaultFilesystemFactory;

  final IsarMediaDataSource _mediaDataSource;
  final FilesystemMediaDataSourceFactory _filesystemDataSourceFactory;

  /// Load media list for a directory
  Future<List<MediaEntity>> call(
    String directoryPath,
    String directoryId, {
    String? bookmarkData,
  }) async {
    final permissionService = PermissionService();
    permissionService.logPermissionEvent(
      'usecase_load_media_start',
      path: directoryPath,
      details: 'directoryId=$directoryId, bookmark_present=${bookmarkData != null}',
    );

    final filesystemDataSource =
        _filesystemDataSourceFactory(BookmarkService.instance, permissionService);

    // Validate permissions before attempting to load
    final validationResult = await filesystemDataSource.validateDirectoryAccess(
      directoryPath,
      bookmarkData: bookmarkData,
    );

    if (!validationResult.canAccess) {
      permissionService.logPermissionEvent(
        'usecase_access_denied',
        path: directoryPath,
        error: validationResult.reason,
      );
      throw Exception('Directory access denied: ${validationResult.reason}');
    }

    try {
      final scannedMediaModels =
          await filesystemDataSource.scanMediaForDirectory(
        directoryPath,
        directoryId,
        bookmarkData: bookmarkData,
      );

      final persistedMediaModels =
          await _mediaDataSource.getMediaForDirectory(directoryId);
      final mergedMediaModels = _mergeWithPersistedTags(
        scannedMediaModels,
        persistedMediaModels,
      );

      permissionService.logPermissionEvent(
        'usecase_load_media_success',
        path: directoryPath,
        details: 'loaded=${mergedMediaModels.length} items',
      );

      // Save media to Isar for favorites functionality
      if (mergedMediaModels.isNotEmpty) {
        await _mediaDataSource.upsertMedia(mergedMediaModels);
      }

      // Convert models to entities for return
      return mergedMediaModels
          .map(
            (model) => MediaEntity(
              id: model.id,
              path: model.path,
              name: model.name,
              type: model.type,
              size: model.size,
              lastModified: model.lastModified,
              tagIds: model.tagIds,
              directoryId: model.directoryId,
              bookmarkData: model.bookmarkData,
            ),
          )
          .toList();
    } catch (e) {
      permissionService.logPermissionEvent(
        'usecase_load_media_failed',
        path: directoryPath,
        error: e.toString(),
      );
      throw Exception('Failed to load media for viewing: $e');
    }
  }

  static FilesystemMediaDataSource _defaultFilesystemFactory(
    BookmarkService bookmarkService,
    PermissionService permissionService,
  ) {
    return FilesystemMediaDataSource(bookmarkService, permissionService);
  }

  List<MediaModel> _mergeWithPersistedTags(
    List<MediaModel> scanned,
    List<MediaModel> persisted,
  ) {
    if (persisted.isEmpty || scanned.isEmpty) {
      return scanned;
    }

    final persistedById = {
      for (final model in persisted) model.id: model,
    };

    return scanned
        .map((model) {
          final existing = persistedById[model.id];
          if (existing == null || existing.tagIds.isEmpty) {
            return model;
          }

          if (model.tagIds.isEmpty) {
            return model.copyWith(tagIds: existing.tagIds);
          }

          final mergedTagIds = List<String>.from(model.tagIds);
          for (final tagId in existing.tagIds) {
            if (!mergedTagIds.contains(tagId)) {
              mergedTagIds.add(tagId);
            }
          }

          return model.copyWith(tagIds: mergedTagIds);
        })
        .toList(growable: false);
  }
}
