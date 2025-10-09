import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/repositories/directory_repository.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/permission_service.dart';
import '../data_sources/filesystem_media_data_source.dart';
import '../data_sources/isar_media_data_source.dart';
import '../models/media_model.dart';
import '../../../../shared/utils/directory_id_utils.dart';

/// Implementation of MediaRepository using filesystem scanning.
class FilesystemMediaRepositoryImpl implements MediaRepository {
  FilesystemMediaRepositoryImpl(
    BookmarkService bookmarkService,
    this._directoryRepository,
    this._mediaDataSource, {
    PermissionService? permissionService,
    FilesystemMediaDataSource? filesystemDataSource,
    bool metadataEnabled = true,
  })  : _filesystemDataSource =
            filesystemDataSource ?? FilesystemMediaDataSource(bookmarkService, permissionService),
        _permissionService = permissionService ?? PermissionService(),
        _metadataEnabled = metadataEnabled;
  final DirectoryRepository _directoryRepository;
  final IsarMediaDataSource _mediaDataSource;
  final FilesystemMediaDataSource _filesystemDataSource;
  final PermissionService _permissionService;
  final bool _metadataEnabled;

  @override
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId) async {
    final directory = await _directoryRepository.getDirectoryById(directoryId);
    if (directory == null) {
      return [];
    }

    return getMediaForDirectoryPath(
      directory.path,
      bookmarkData: directory.bookmarkData,
    );
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    _permissionService.logPermissionEvent(
      'repository_get_media_start',
      path: directoryPath,
      details: 'directoryId=$directoryId, bookmark_present=${bookmarkData != null}',
    );

    // Validate permissions before attempting to scan
    final validationResult = await _filesystemDataSource.validateDirectoryAccess(
      directoryPath,
      bookmarkData: bookmarkData,
    );

    if (!validationResult.canAccess) {
      _permissionService.logPermissionEvent(
        'repository_access_denied',
        path: directoryPath,
        error: validationResult.reason,
      );

      if (validationResult.requiresRecovery) {
        throw PermissionError('Directory access denied: ${validationResult.reason}. Recovery required.');
      } else {
        throw DirectoryAccessDeniedError('Directory access denied: ${validationResult.reason}');
      }
    }

    try {
      final models = await _filesystemDataSource.scanMediaForDirectory(
        directoryPath,
        directoryId,
        bookmarkData: bookmarkData,
        enableMetadata: _metadataEnabled,
      );

      // Merge tags from persisted storage
      final mergedModels = await _mergeTagsWithLocalStorage(models);

      await _mediaDataSource.upsertMedia(mergedModels);

      _permissionService.logPermissionEvent(
        'repository_get_media_success',
        path: directoryPath,
        details: 'found=${mergedModels.length} items',
      );

      return mergedModels.map(_modelToEntity).toList();
    } catch (e) {
      _permissionService.logPermissionEvent(
        'repository_get_media_failed',
        path: directoryPath,
        error: e.toString(),
      );
      throw DirectoryScanError('Failed to get media for directory: $e');
    }
  }

  @override
  Future<MediaEntity?> getMediaById(String id) async {
    final allMedia = await _mediaDataSource.getMedia();
    final localMedia = allMedia.where((media) => media.id == id).firstOrNull;

    if (localMedia == null) {
      return _scanDirectoriesForMedia(id);
    }

    final directory = await _directoryRepository.getDirectoryById(localMedia.directoryId);
    if (directory == null) {
      return _modelToEntity(localMedia);
    }

    final refreshedMedia = await getMediaByIdFromDirectory(
      id,
      directory.path,
      bookmarkData: directory.bookmarkData,
      persistedTagIds: localMedia.tagIds,
    );

    if (refreshedMedia != null) {
      return refreshedMedia;
    }

    return _modelToEntity(localMedia);
  }

  /// Gets media by ID from a specific directory.
  Future<MediaEntity?> getMediaByIdFromDirectory(
    String id,
    String directoryPath, {
    String? bookmarkData,
    List<String>? persistedTagIds,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    final model = await _filesystemDataSource.getMediaById(
      id,
      directoryPath,
      directoryId,
      bookmarkData: bookmarkData,
      enableMetadata: _metadataEnabled,
    );
    if (model == null) {
      return null;
    }

    var mergedModel = (await _mergeTagsWithLocalStorage([model])).first;
    if (persistedTagIds != null) {
      mergedModel = mergedModel.copyWith(tagIds: persistedTagIds);
    }
    await _mediaDataSource.upsertMedia([mergedModel]);
    return _modelToEntity(mergedModel);
  }

  @override
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      // If no tags specified, return all media from all directories
      final directories = await _directoryRepository.getDirectories();
      final allMedia = <MediaEntity>[];
      for (final directory in directories) {
        final media = await getMediaForDirectoryPath(
          directory.path,
          bookmarkData: directory.bookmarkData,
        );
        allMedia.addAll(media);
      }
      return allMedia;
    }

    // Get media from local storage that have the specified tags
    final allLocalMedia = await _mediaDataSource.getMedia();
    final filteredLocalMedia = allLocalMedia
        .where((media) => media.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();

    // Group by directoryId to avoid scanning the same directory multiple times
    final mediaByDirectory = <String, List<String>>{};
    for (final media in filteredLocalMedia) {
      mediaByDirectory.putIfAbsent(media.directoryId, () => []).add(media.id);
    }

    final result = <MediaEntity>[];
    for (final entry in mediaByDirectory.entries) {
      final directoryId = entry.key;
      final mediaIds = entry.value;

      final directory = await _directoryRepository.getDirectoryById(directoryId);
      if (directory == null) continue;

      final directoryMedia = await getMediaForDirectoryPath(
        directory.path,
        bookmarkData: directory.bookmarkData,
      );

      // Filter to only include media with matching IDs
      result.addAll(directoryMedia.where((media) => mediaIds.contains(media.id)));
    }

    return result;
  }

  @override
  Future<List<MediaEntity>> filterMediaByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    final scanned = await _filesystemDataSource.scanMediaForDirectory(
      directoryPath,
      directoryId,
      bookmarkData: bookmarkData,
      enableMetadata: _metadataEnabled,
    );
    final merged = await _mergeTagsWithLocalStorage(scanned);
    final filtered = tagIds.isEmpty
        ? merged
        : merged.where(
            (media) => media.tagIds.any((tagId) => tagIds.contains(tagId)),
          );
    await _mediaDataSource.upsertMedia(merged);
    return filtered.map(_modelToEntity).toList();
  }

  /// Filters media by tags from a specific directory.
  Future<List<MediaEntity>> filterMediaByTagsFromDirectory(
    List<String> tagIds,
    String directoryPath,
    String directoryId, {
    String? bookmarkData,
  }) async {
    final scanned = await _filesystemDataSource.scanMediaForDirectory(
      directoryPath,
      directoryId,
      bookmarkData: bookmarkData,
      enableMetadata: _metadataEnabled,
    );
    final merged = await _mergeTagsWithLocalStorage(scanned);
    final filtered = tagIds.isEmpty
        ? merged
        : merged.where(
            (media) => media.tagIds.any((tagId) => tagIds.contains(tagId)),
          );
    await _mediaDataSource.upsertMedia(merged);
    return filtered.map(_modelToEntity).toList();
  }

  @override
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    await _mediaDataSource.updateMediaTags(mediaId, tagIds);
  }

  /// Merges tags from local storage with filesystem-scanned media.
  Future<List<MediaModel>> _mergeTagsWithLocalStorage(List<MediaModel> scannedMedia) async {
    final existingMedia = await _mediaDataSource.getMedia();
    final existingMediaMap = {for (final m in existingMedia) m.id: m};

    // Convert entities back to models for persistence, merging tagIds from persisted data
    return scannedMedia.map((entity) {
      final existing = existingMediaMap[entity.id];
      return entity.copyWith(
        tagIds: existing?.tagIds ?? entity.tagIds,
        thumbnailPath: entity.thumbnailPath ?? existing?.thumbnailPath,
        width: entity.width ?? existing?.width,
        height: entity.height ?? existing?.height,
        durationSeconds: entity.durationSeconds ?? existing?.durationSeconds,
        metadata: entity.metadata ?? existing?.metadata,
      );
    }).toList();
  }

  /// Converts MediaModel to MediaEntity.
  MediaEntity _modelToEntity(MediaModel model) {
    return MediaEntity(
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
    );
  }

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _mediaDataSource.removeMediaForDirectory(directoryId);
  }

  Future<MediaEntity?> _scanDirectoriesForMedia(String id) async {
    final directories = await _directoryRepository.getDirectories();
    for (final directory in directories) {
      final directoryId = generateDirectoryId(directory.path);
      final model = await _filesystemDataSource.getMediaById(
        id,
        directory.path,
        directoryId,
        bookmarkData: directory.bookmarkData,
      );

      if (model != null) {
        return _modelToEntity(model);
      }
    }

    return null;
  }
}
