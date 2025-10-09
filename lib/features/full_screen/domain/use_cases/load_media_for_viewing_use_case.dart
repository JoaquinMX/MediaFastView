import '../../../../core/services/permission_service.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/data/data_sources/filesystem_media_data_source.dart';
import '../../../media_library/data/data_sources/isar_media_data_source.dart';

/// Use case for loading media for full-screen viewing
class LoadMediaForViewingUseCase {
  const LoadMediaForViewingUseCase(
    this._mediaDataSource,
    this._filesystemDataSource,
    this._permissionService,
  );

  final IsarMediaDataSource _mediaDataSource;
  final FilesystemMediaDataSource _filesystemDataSource;
  final PermissionService _permissionService;

  /// Load media list for a directory
  Future<List<MediaEntity>> call(String directoryPath, String directoryId, {String? bookmarkData}) async {
    _permissionService.logPermissionEvent(
      'usecase_load_media_start',
      path: directoryPath,
      details: 'directoryId=$directoryId, bookmark_present=${bookmarkData != null}',
    );

    // Validate permissions before attempting to load
    final validationResult = await _filesystemDataSource.validateDirectoryAccess(
      directoryPath,
      bookmarkData: bookmarkData,
    );

    if (!validationResult.canAccess) {
      _permissionService.logPermissionEvent(
        'usecase_access_denied',
        path: directoryPath,
        error: validationResult.reason,
      );
      throw Exception('Directory access denied: ${validationResult.reason}');
    }

    try {
      final mediaModels = await _filesystemDataSource.scanMediaForDirectory(
        directoryPath,
        directoryId,
        bookmarkData: bookmarkData,
      );

      _permissionService.logPermissionEvent(
        'usecase_load_media_success',
        path: directoryPath,
        details: 'loaded=${mediaModels.length} items',
      );

      // Save media to SharedPreferences for favorites functionality
      if (mediaModels.isNotEmpty) {
        await _mediaDataSource.upsertMedia(mediaModels);
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
        thumbnailPath: model.thumbnailPath,
        width: model.width,
        height: model.height,
        duration: model.durationSeconds == null
            ? null
            : Duration(milliseconds: (model.durationSeconds! * 1000).round()),
        metadata: model.metadata,
      )).toList();
    } catch (e) {
      _permissionService.logPermissionEvent(
        'usecase_load_media_failed',
        path: directoryPath,
        error: e.toString(),
      );
      throw Exception('Failed to load media for viewing: $e');
    }
  }
}
