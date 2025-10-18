import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/repositories/directory_repository.dart';
import '../data_sources/local_directory_data_source.dart';
import '../isar/isar_directory_data_source.dart';
import '../isar/isar_media_data_source.dart';
import '../models/directory_model.dart';

/// Implementation of DirectoryRepository using Isar-backed persistence and the local file system.
class DirectoryRepositoryImpl implements DirectoryRepository {
  DirectoryRepositoryImpl(
    this._isarDirectoryDataSource,
    this._localDirectoryDataSource,
    this._bookmarkService,
    this._permissionService,
    this._isarMediaDataSource,
  );

  final IsarDirectoryDataSource _isarDirectoryDataSource;
  final IsarMediaDataSource _isarMediaDataSource;
  final LocalDirectoryDataSource _localDirectoryDataSource;
  final BookmarkService _bookmarkService;
  final PermissionService _permissionService;

  @override
  Future<List<DirectoryEntity>> getDirectories() async {
    final models = await _isarDirectoryDataSource.getDirectories();
    final entities = <DirectoryEntity>[];

    for (final model in models) {
      final normalizedModel = await _ensureStableDirectoryId(model);
      DirectoryEntity entity;
      try {
        if (normalizedModel.bookmarkData != null &&
            normalizedModel.bookmarkData!.isNotEmpty) {
          final validationResult = await _permissionService.validateAndRenewBookmark(
            normalizedModel.bookmarkData!,
            normalizedModel.path,
          );

          if (validationResult.renewedBookmarkData != null) {
            // Update stored bookmark data
            await updateDirectoryBookmark(
              normalizedModel.id,
              validationResult.renewedBookmarkData,
            );
            LoggingService.instance.info('Bookmark renewed and updated for directory ${normalizedModel.path}');
          }

          if (validationResult.isValid) {
            entity = await _resolveBookmarkForModel(
              normalizedModel.copyWith(
                bookmarkData:
                    validationResult.renewedBookmarkData ?? normalizedModel.bookmarkData,
              ),
            );
          } else {
            // Bookmark invalid and renewal failed
            throw BookmarkInvalidError(
              'Bookmark for directory ${normalizedModel.path} is invalid and could not be renewed. Please re-select the directory.',
              normalizedModel.id,
              normalizedModel.path,
            );
          }
        } else {
          LoggingService.instance.debug('No bookmark data available for directory ${normalizedModel.path}, using stored path');
          entity = _modelToEntity(normalizedModel);
        }
      } catch (e) {
        if (e is BookmarkInvalidError) {
          rethrow; // Re-throw bookmark errors to be handled by UI
        }
        LoggingService.instance.error('Failed to resolve bookmark for directory ${normalizedModel.path}: $e');
        // Fall back to the stored path if bookmark resolution fails
        entity = _modelToEntity(normalizedModel);
      }
      entities.add(entity);
    }

    return entities;
  }

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async {
    final directories = await getDirectories();
    return directories.where((dir) => dir.id == id).firstOrNull;
  }

  @override
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false}) async {
    // Validate directory exists on file system
    LoggingService.instance.debug('Validating directory access for: ${directory.path}');
    final isValid = await _localDirectoryDataSource.validateDirectory(directory);
    if (!isValid) {
      LoggingService.instance.error('Directory validation failed for: ${directory.path}');
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }
    LoggingService.instance.info('Directory validation successful for: ${directory.path}');

    // Check if directory already exists
    final directories = await getDirectories();
    final existing = directories.where((d) => d.path == directory.path).firstOrNull;

    // Create security-scoped bookmark for macOS
    String? bookmarkData;
    try {
      final createdBookmark = await _bookmarkService.createBookmark(directory.path);
      bookmarkData = createdBookmark;
      LoggingService.instance.info('Bookmark created successfully for: ${directory.path}');

      // Validate the created bookmark on macOS
      if (createdBookmark.isNotEmpty) {
        final validationResult = await _permissionService.validateBookmark(createdBookmark);
        if (!validationResult.isValid) {
          LoggingService.instance.error('CRITICAL: Created bookmark is invalid for directory ${directory.path}');
          if (!silent) {
            // Try to recover access (shows dialog)
            final recoveryResult = await _permissionService.recoverDirectoryAccess(directory.path);
            if (recoveryResult != null) {
              LoggingService.instance.info('Recovered access for directory: ${recoveryResult.directoryPath}');
              // Use bookmark data from recovery if available, otherwise create new one
              final renewedBookmark = recoveryResult.bookmarkData ??
                  await _bookmarkService.createBookmark(recoveryResult.directoryPath);
              bookmarkData = renewedBookmark;
              final validationResult2 = await _permissionService.validateBookmark(renewedBookmark);
              if (!validationResult2.isValid) {
                LoggingService.instance.error('CRITICAL: Recovered bookmark is still invalid');
                bookmarkData = null;
              }
              // Update directory path if different
              if (recoveryResult.directoryPath != directory.path) {
                directory = directory.copyWith(
                  path: recoveryResult.directoryPath,
                  id: generateDirectoryId(recoveryResult.directoryPath),
                );
              }
            } else {
              LoggingService.instance.error('Recovery failed for directory ${directory.path}');
              bookmarkData = null;
            }
          } else {
            // Silent mode: don't attempt recovery, just set bookmark to null
            LoggingService.instance.warning('Skipping recovery for directory ${directory.path} in silent mode');
            bookmarkData = null;
          }
        }
      }
    } catch (e) {
      if (e is BookmarkInvalidError) {
        rethrow;
      }
      LoggingService.instance.warning('Failed to create bookmark for: ${directory.path}, proceeding without bookmark: $e');
      // Continue without bookmark - this allows the app to work on non-macOS platforms
    }

    final preservedTagIds = directory.tagIds.isNotEmpty
        ? directory.tagIds
        : (existing?.tagIds ?? const <String>[]);

    String? resolvedBookmarkData;
    if (bookmarkData != null && bookmarkData.isNotEmpty) {
      resolvedBookmarkData = bookmarkData;
    } else if (directory.bookmarkData != null && directory.bookmarkData!.isNotEmpty) {
      resolvedBookmarkData = directory.bookmarkData;
    } else {
      resolvedBookmarkData = existing?.bookmarkData;
    }

    final directoryToPersist = directory.copyWith(
      tagIds: preservedTagIds,
      bookmarkData: resolvedBookmarkData,
    );

    final model = _entityToModel(directoryToPersist);
    if (existing != null) {
      await _isarDirectoryDataSource.updateDirectory(model);
    } else {
      await _isarDirectoryDataSource.addDirectory(model);
    }
  }

  @override
  Future<void> removeDirectory(String id) async {
    // Remove the directory itself
    await _isarDirectoryDataSource.removeDirectory(id);
  }

  @override
  Future<List<DirectoryEntity>> searchDirectories(String query) async {
    final directories = await getDirectories();
    if (query.isEmpty) return directories;

    final lowerQuery = query.toLowerCase();
    return directories
        .where(
          (dir) =>
              dir.name.toLowerCase().contains(lowerQuery) ||
              dir.path.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  @override
  Future<List<DirectoryEntity>> filterDirectoriesByTags(
    List<String> tagIds,
  ) async {
    if (tagIds.isEmpty) return getDirectories();

    final directories = await getDirectories();
    return directories
        .where((dir) => dir.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();
  }

  @override
  Future<void> updateDirectoryTags(
    String directoryId,
    List<String> tagIds,
  ) async {
    final directory = await getDirectoryById(directoryId);
    if (directory != null) {
      final updatedDirectory = directory.copyWith(tagIds: tagIds);
      final model = _entityToModel(updatedDirectory);
      await _isarDirectoryDataSource.updateDirectory(model);
    }
  }

  @override
  Future<BatchUpdateResult> updateDirectoryTagsBatch(
    Map<String, List<String>> directoryTags,
  ) async {
    if (directoryTags.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final models = await _isarDirectoryDataSource.getDirectories();
    final indexById = {
      for (var i = 0; i < models.length; i++) models[i].id: i,
    };

    final successes = <String>[];
    final failures = <String, String>{};

    for (final entry in directoryTags.entries) {
      final index = indexById[entry.key];
      if (index == null) {
        failures[entry.key] = 'Directory not found';
        continue;
      }

      models[index] = models[index].copyWith(tagIds: entry.value);
      successes.add(entry.key);
    }

    if (successes.isNotEmpty) {
      await _isarDirectoryDataSource.saveDirectories(models);
      LoggingService.instance.info(
        'Updated tags for ${successes.length} directories in a single batch.',
      );
    }

    if (failures.isNotEmpty) {
      LoggingService.instance.warning(
        'Failed to update tags for directories: ${failures.keys.join(', ')}',
      );
    }

    return BatchUpdateResult(
      successfulIds: successes,
      failureReasons: failures,
    );
  }

  @override
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData) async {
    final directory = await getDirectoryById(directoryId);
    if (directory != null) {
      final updatedDirectory = directory.copyWith(bookmarkData: bookmarkData);
      final model = _entityToModel(updatedDirectory);
      await _isarDirectoryDataSource.updateDirectory(model);
    }
  }

  /// Ensures that stored directory IDs use the shared hashing strategy.
  Future<DirectoryModel> _ensureStableDirectoryId(DirectoryModel model) async {
    final expectedId = generateDirectoryId(model.path);
    if (model.id == expectedId) {
      return model;
    }

    LoggingService.instance.warning(
      'Detected legacy directory ID for ${model.path}. Updating to stable SHA-256 hash.',
    );

    final updatedModel = model.copyWith(id: expectedId);

    await _isarMediaDataSource.migrateDirectoryId(model.id, expectedId);
    await _isarDirectoryDataSource.removeDirectory(model.id);
    await _isarDirectoryDataSource.addDirectory(updatedModel);

    return updatedModel;
  }

  /// Converts DirectoryModel to DirectoryEntity.
  DirectoryEntity _modelToEntity(DirectoryModel model) {
    return DirectoryEntity(
      id: model.id,
      path: model.path,
      name: model.name,
      thumbnailPath: model.thumbnailPath,
      tagIds: model.tagIds,
      lastModified: model.lastModified,
      bookmarkData: model.bookmarkData,
    );
  }

  /// Converts DirectoryEntity to DirectoryModel.
  DirectoryModel _entityToModel(DirectoryEntity entity) {
    return DirectoryModel(
      id: entity.id,
      path: entity.path,
      name: entity.name,
      thumbnailPath: entity.thumbnailPath,
      tagIds: entity.tagIds,
      lastModified: entity.lastModified,
      bookmarkData: entity.bookmarkData,
    );
  }

  @override
  Future<void> clearAllDirectories() async {
    try {
      await _isarDirectoryDataSource.clearDirectories();
      LoggingService.instance.info('Successfully cleared all directory data from cache');
    } catch (e) {
      LoggingService.instance.error('Failed to clear directory cache: $e');
      rethrow;
    }
  }

  /// Resolves bookmark for a directory model and returns the corresponding entity.
  /// If bookmark resolution fails, falls back to the stored path.
  Future<DirectoryEntity> _resolveBookmarkForModel(DirectoryModel model) async {
    if (model.bookmarkData == null || model.bookmarkData!.isEmpty) {
      // No bookmark data, use stored path
      return _modelToEntity(model);
    }

    try {
      // Check if bookmark is still valid
      final validationResult = await _permissionService.validateBookmark(model.bookmarkData!);
      if (!validationResult.isValid) {
        LoggingService.instance.error('CRITICAL: Bookmark validation failed during resolution for directory: ${model.path} - bookmark has expired. Falling back to stored path: ${model.path}');
        // Fall back to stored path
        return _modelToEntity(model);
      }

      // Resolve bookmark to get current path
      final resolvedPath = await _bookmarkService.resolveBookmark(model.bookmarkData!);
      LoggingService.instance.info('Bookmark resolved successfully for directory: ${model.path} -> $resolvedPath');

      // Create entity with resolved path but keep original bookmark data
      return DirectoryEntity(
        id: model.id,
        path: resolvedPath,
        name: model.name,
        thumbnailPath: model.thumbnailPath,
        tagIds: model.tagIds,
        lastModified: model.lastModified,
        bookmarkData: model.bookmarkData,
      );
    } catch (e) {
      LoggingService.instance.error('Failed to resolve bookmark for directory ${model.path}: $e');
      // Fall back to stored path
      return _modelToEntity(model);
    }
  }
}
