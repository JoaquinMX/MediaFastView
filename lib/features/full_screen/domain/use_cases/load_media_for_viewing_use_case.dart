import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/data/data_sources/filesystem_media_data_source.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';

/// Use case for loading media for full-screen viewing
class LoadMediaForViewingUseCase {
  const LoadMediaForViewingUseCase(this._mediaDataSource);

  final IsarMediaDataSource _mediaDataSource;

  /// Load media list for a directory
  Future<List<MediaEntity>> call(String directoryPath, String directoryId, {String? bookmarkData}) async {
    final permissionService = PermissionService();
    permissionService.logPermissionEvent(
      'usecase_load_media_start',
      path: directoryPath,
      details: 'directoryId=$directoryId, bookmark_present=${bookmarkData != null}',
    );

    final filesystemDataSource = FilesystemMediaDataSource(BookmarkService.instance, permissionService);

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
      final mediaModels = await filesystemDataSource.scanMediaForDirectory(directoryPath, directoryId, bookmarkData: bookmarkData);

      permissionService.logPermissionEvent(
        'usecase_load_media_success',
        path: directoryPath,
        details: 'loaded=${mediaModels.length} items',
      );

      // Save media to the persistent cache for favorites functionality
      if (mediaModels.isNotEmpty) {
        await _mediaDataSource.addMedia(mediaModels);
      }

      // Convert models to entities for return
      return mediaModels.map((model) => MediaEntity(
        id: model.id,
        path: model.path,
        name: model.name,
        type: model.type,
        size: model.size,
        lastModified: model.lastModified,
        tagIds: model.tagIds,
        directoryId: model.directoryId,
        bookmarkData: model.bookmarkData,
      )).toList();
    } catch (e) {
      permissionService.logPermissionEvent(
        'usecase_load_media_failed',
        path: directoryPath,
        error: e.toString(),
      );
      throw Exception('Failed to load media for viewing: $e');
    }
  }
}
