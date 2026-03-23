import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/repositories/directory_repository.dart';
import '../data_sources/filesystem_media_data_source.dart';
import '../data_sources/local_directory_data_source.dart';
import '../isar/isar_directory_data_source.dart';
import '../isar/isar_media_data_source.dart';
import '../models/directory_model.dart';
import '../models/media_model.dart';

/// Implementation of DirectoryRepository using Isar-backed persistence and the local file system.
class DirectoryRepositoryImpl implements DirectoryRepository {
  DirectoryRepositoryImpl(
    this._isarDirectoryDataSource,
    this._localDirectoryDataSource,
    this._bookmarkService,
    this._permissionService,
    this._isarMediaDataSource,
    this._filesystemMediaDataSource,
  );

  final IsarDirectoryDataSource _isarDirectoryDataSource;
  final IsarMediaDataSource _isarMediaDataSource;
  final LocalDirectoryDataSource _localDirectoryDataSource;
  final BookmarkService _bookmarkService;
  final PermissionService _permissionService;
  final FilesystemMediaDataSource _filesystemMediaDataSource;

  @override
  Future<List<DirectoryEntity>> getDirectories() async {
    final models = await _isarDirectoryDataSource.getDirectories();
    final entities = <DirectoryEntity>[];

    for (final model in models) {
      final normalizedModel = await _ensureStableDirectoryId(model);
      final entity = await _buildEntityFromModel(normalizedModel);
      entities.add(entity);
    }

    return entities;
  }

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async {
    final model = await _isarDirectoryDataSource.getDirectoryById(id);
    if (model != null) {
      final normalizedModel = await _ensureStableDirectoryId(model);
      return _buildEntityFromModel(normalizedModel);
    }

    final models = await _isarDirectoryDataSource.getDirectories();
    for (final candidate in models) {
      final normalizedModel = await _ensureStableDirectoryId(candidate);
      if (normalizedModel.id != id) {
        continue;
      }
      return _buildEntityFromModel(normalizedModel);
    }

    return null;
  }

  @override
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false}) async {
    LoggingService.instance.debug(
      'Validating directory access for: ${directory.path}',
    );
    final isValid = await _localDirectoryDataSource.validateDirectory(directory);
    if (!isValid) {
      LoggingService.instance.error(
        'Directory validation failed for: ${directory.path}',
      );
      throw ArgumentError('Directory does not exist: ${directory.path}');
    }
    LoggingService.instance.info(
      'Directory validation successful for: ${directory.path}',
    );

    final directories = await getDirectories();
    final existing = directories.where((d) => d.path == directory.path).firstOrNull;

    String? bookmarkData;
    if (Platform.isMacOS) {
      try {
        final createdBookmark = await _bookmarkService.createBookmark(
          directory.path,
        );
        bookmarkData = createdBookmark;
        LoggingService.instance.info(
          'Bookmark created successfully for: ${directory.path}',
        );

        if (createdBookmark.isNotEmpty) {
          final validationResult = await _permissionService.validateBookmark(
            createdBookmark,
          );
          if (!validationResult.isValid) {
            LoggingService.instance.error(
              'CRITICAL: Created bookmark is invalid for directory '
              '${directory.path}',
            );
            if (!silent) {
              final recoveryResult = await _permissionService
                  .recoverDirectoryAccess(directory.path);
              if (recoveryResult != null) {
                LoggingService.instance.info(
                  'Recovered access for directory: '
                  '${recoveryResult.directoryPath}',
                );
                final renewedBookmark = recoveryResult.bookmarkData ??
                    await _bookmarkService.createBookmark(
                      recoveryResult.directoryPath,
                    );
                bookmarkData = renewedBookmark;
                final validationResult2 = await _permissionService
                    .validateBookmark(renewedBookmark);
                if (!validationResult2.isValid) {
                  LoggingService.instance.error(
                    'CRITICAL: Recovered bookmark is still invalid',
                  );
                  bookmarkData = null;
                }
                if (recoveryResult.directoryPath != directory.path) {
                  directory = directory.copyWith(
                    path: recoveryResult.directoryPath,
                    id: generateDirectoryId(recoveryResult.directoryPath),
                  );
                }
              } else {
                LoggingService.instance.error(
                  'Recovery failed for directory ${directory.path}',
                );
                bookmarkData = null;
              }
            } else {
              LoggingService.instance.warning(
                'Skipping recovery for directory ${directory.path} in silent mode',
              );
              bookmarkData = null;
            }
          }
        }
      } catch (e) {
        if (e is BookmarkInvalidError) {
          rethrow;
        }
        LoggingService.instance.warning(
          'Failed to create bookmark for: ${directory.path}, '
          'proceeding without bookmark: $e',
        );
      }
    }

    final preservedTagIds = directory.tagIds.isNotEmpty
        ? directory.tagIds
        : (existing?.tagIds ?? const <String>[]);

    String? resolvedBookmarkData;
    if (bookmarkData != null && bookmarkData.isNotEmpty) {
      resolvedBookmarkData = bookmarkData;
    } else if (directory.bookmarkData != null &&
        directory.bookmarkData!.isNotEmpty) {
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
    await _isarDirectoryDataSource.removeDirectory(id);
  }

  @override
  Future<List<DirectoryEntity>> searchDirectories(String query) async {
    final directories = await getDirectories();
    if (query.isEmpty) {
      return directories;
    }

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
    if (tagIds.isEmpty) {
      return getDirectories();
    }

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
    return _isarDirectoryDataSource.updateDirectoryTagsBatch(directoryTags);
  }

  @override
  Future<void> updateDirectoryBookmark(
    String directoryId,
    String? bookmarkData,
  ) async {
    final model = await _isarDirectoryDataSource.getDirectoryById(directoryId);
    if (model == null) {
      return;
    }

    final normalizedModel = await _ensureStableDirectoryId(model);
    final updatedModel = normalizedModel.copyWith(bookmarkData: bookmarkData);
    await _isarDirectoryDataSource.updateDirectory(updatedModel);
  }

  @override
  Future<void> updateDirectoryMetadata(
    String directoryId, {
    String? path,
    String? name,
    String? bookmarkData,
  }) async {
    final model = await _isarDirectoryDataSource.getDirectoryById(directoryId);
    if (model == null) {
      LoggingService.instance.warning(
        'Attempted to update directory metadata for unknown id: $directoryId',
      );
      return;
    }

    final normalizedModel = await _ensureStableDirectoryId(model);
    var updatedModel = normalizedModel;
    var targetId = normalizedModel.id;

    if (path != null && path.isNotEmpty && path != normalizedModel.path) {
      targetId = generateDirectoryId(path);
      final derivedName = p.basename(path);
      final updatedName = name?.isNotEmpty == true
          ? name!
          : (derivedName.isNotEmpty ? derivedName : normalizedModel.name);

      updatedModel = updatedModel.copyWith(
        id: targetId,
        path: path,
        name: updatedName,
      );
    } else if (name != null && name.isNotEmpty && name != normalizedModel.name) {
      updatedModel = updatedModel.copyWith(name: name);
    }

    if (bookmarkData != null && bookmarkData != normalizedModel.bookmarkData) {
      updatedModel = updatedModel.copyWith(bookmarkData: bookmarkData);
    }

    if (targetId != normalizedModel.id) {
      await _isarMediaDataSource.migrateDirectoryId(normalizedModel.id, targetId);
      await _isarDirectoryDataSource.removeDirectory(normalizedModel.id);
      await _isarDirectoryDataSource.addDirectory(updatedModel);
    } else {
      await _isarDirectoryDataSource.updateDirectory(updatedModel);
    }
  }

  @override
  Future<void> refreshChangedLibraryRoots() async {
    final models = await _isarDirectoryDataSource.getDirectories();

    for (final model in models) {
      final normalizedModel = await _ensureStableDirectoryId(model);
      final directory = _modelToEntity(normalizedModel);

      try {
        final fingerprint = await _localDirectoryDataSource
            .fingerprintDirectoryTree(directory);
        if (!_hasDirectoryFingerprintChanged(normalizedModel, fingerprint)) {
          continue;
        }

        final rescannedMedia = await _filesystemMediaDataSource
            .scanMediaForDirectory(
              directory.path,
              directory.id,
              bookmarkData: directory.bookmarkData,
            );
        await _replaceCachedMediaForDirectory(
          directoryId: directory.id,
          rescannedMedia: rescannedMedia,
        );

        await _isarDirectoryDataSource.updateDirectory(
          normalizedModel.copyWith(
            lastScanAt: DateTime.now(),
            lastKnownTreeModified: fingerprint.lastKnownTreeModified,
            lastKnownChildDirectoryCount:
                fingerprint.lastKnownChildDirectoryCount,
            lastKnownMediaFileCount: fingerprint.lastKnownMediaFileCount,
          ),
        );
      } catch (error, stackTrace) {
        LoggingService.instance.warning(
          'Failed to refresh library root ${directory.path}: $error',
        );
        LoggingService.instance.debug(stackTrace.toString());
      }
    }
  }

  Future<void> _replaceCachedMediaForDirectory({
    required String directoryId,
    required List<MediaModel> rescannedMedia,
  }) async {
    final existingMedia = await _isarMediaDataSource.getMediaForDirectory(
      directoryId,
    );
    final existingMediaById = {
      for (final media in existingMedia) media.id: media,
    };

    final mergedMedia = rescannedMedia.map((media) {
      final existing = existingMediaById[media.id];
      if (existing == null || existing.tagIds.isEmpty) {
        return media;
      }

      final mergedTagIds = <String>{...existing.tagIds, ...media.tagIds};
      return media.copyWith(tagIds: mergedTagIds.toList(growable: false));
    }).toList(growable: false);

    await _isarMediaDataSource.removeMediaForDirectory(directoryId);
    if (mergedMedia.isEmpty) {
      return;
    }
    await _isarMediaDataSource.addMedia(mergedMedia);
  }

  bool _hasDirectoryFingerprintChanged(
    DirectoryModel model,
    DirectoryTreeFingerprint fingerprint,
  ) {
    return model.lastKnownTreeModified != fingerprint.lastKnownTreeModified ||
        model.lastKnownChildDirectoryCount !=
            fingerprint.lastKnownChildDirectoryCount ||
        model.lastKnownMediaFileCount != fingerprint.lastKnownMediaFileCount;
  }

  Future<DirectoryModel> _ensureStableDirectoryId(DirectoryModel model) async {
    final expectedId = generateDirectoryId(model.path);
    if (model.id == expectedId) {
      return model;
    }

    LoggingService.instance.warning(
      'Detected legacy directory ID for ${model.path}. Updating to stable '
      'SHA-256 hash.',
    );

    final updatedModel = model.copyWith(id: expectedId);

    await _isarMediaDataSource.migrateDirectoryId(model.id, expectedId);
    await _isarDirectoryDataSource.removeDirectory(model.id);
    await _isarDirectoryDataSource.addDirectory(updatedModel);

    return updatedModel;
  }

  Future<DirectoryEntity> _buildEntityFromModel(DirectoryModel model) async {
    try {
      if (model.bookmarkData != null && model.bookmarkData!.isNotEmpty) {
        final validationResult = await _permissionService
            .validateAndRenewBookmark(model.bookmarkData!, model.path);

        if (validationResult.renewedBookmarkData != null) {
          await updateDirectoryBookmark(
            model.id,
            validationResult.renewedBookmarkData,
          );
          LoggingService.instance.info(
            'Bookmark renewed and updated for directory ${model.path}',
          );
        }

        if (validationResult.isValid) {
          return _resolveBookmarkForModel(
            model.copyWith(
              bookmarkData:
                  validationResult.renewedBookmarkData ?? model.bookmarkData,
            ),
          );
        }

        throw BookmarkInvalidError(
          'Bookmark for directory ${model.path} is invalid and could not be '
          'renewed. Please re-select the directory.',
          model.id,
          model.path,
        );
      }

      LoggingService.instance.debug(
        'No bookmark data available for directory ${model.path}, using stored path',
      );
      return _modelToEntity(model);
    } catch (error) {
      if (error is BookmarkInvalidError) {
        rethrow;
      }

      LoggingService.instance.error(
        'Failed to resolve bookmark for directory ${model.path}: $error',
      );
      return _modelToEntity(model);
    }
  }

  DirectoryEntity _modelToEntity(DirectoryModel model) {
    return DirectoryEntity(
      id: model.id,
      path: model.path,
      name: model.name,
      thumbnailPath: model.thumbnailPath,
      tagIds: model.tagIds,
      lastModified: model.lastModified,
      bookmarkData: model.bookmarkData,
      lastScanAt: model.lastScanAt,
      lastKnownTreeModified: model.lastKnownTreeModified,
      lastKnownChildDirectoryCount: model.lastKnownChildDirectoryCount,
      lastKnownMediaFileCount: model.lastKnownMediaFileCount,
    );
  }

  DirectoryModel _entityToModel(DirectoryEntity entity) {
    return DirectoryModel(
      id: entity.id,
      path: entity.path,
      name: entity.name,
      thumbnailPath: entity.thumbnailPath,
      tagIds: entity.tagIds,
      lastModified: entity.lastModified,
      bookmarkData: entity.bookmarkData,
      lastScanAt: entity.lastScanAt,
      lastKnownTreeModified: entity.lastKnownTreeModified,
      lastKnownChildDirectoryCount: entity.lastKnownChildDirectoryCount,
      lastKnownMediaFileCount: entity.lastKnownMediaFileCount,
    );
  }

  @override
  Future<void> clearAllDirectories() async {
    try {
      await _isarDirectoryDataSource.clearDirectories();
      LoggingService.instance.info(
        'Successfully cleared all directory data from cache',
      );
    } catch (e) {
      LoggingService.instance.error('Failed to clear directory cache: $e');
      rethrow;
    }
  }

  Future<DirectoryEntity> _resolveBookmarkForModel(DirectoryModel model) async {
    if (model.bookmarkData == null || model.bookmarkData!.isEmpty) {
      return _modelToEntity(model);
    }

    try {
      final validationResult = await _permissionService.validateBookmark(
        model.bookmarkData!,
      );
      if (!validationResult.isValid) {
        LoggingService.instance.error(
          'CRITICAL: Bookmark validation failed during resolution for '
          'directory: ${model.path} - bookmark has expired. Falling back to '
          'stored path: ${model.path}',
        );
        return _modelToEntity(model);
      }

      final resolvedPath = await _bookmarkService.resolveBookmark(
        model.bookmarkData!,
      );
      LoggingService.instance.info(
        'Bookmark resolved successfully for directory: ${model.path} -> '
        '$resolvedPath',
      );

      return DirectoryEntity(
        id: model.id,
        path: resolvedPath,
        name: model.name,
        thumbnailPath: model.thumbnailPath,
        tagIds: model.tagIds,
        lastModified: model.lastModified,
        bookmarkData: model.bookmarkData,
        lastScanAt: model.lastScanAt,
        lastKnownTreeModified: model.lastKnownTreeModified,
        lastKnownChildDirectoryCount: model.lastKnownChildDirectoryCount,
        lastKnownMediaFileCount: model.lastKnownMediaFileCount,
      );
    } catch (e) {
      LoggingService.instance.error(
        'Failed to resolve bookmark for directory ${model.path}: $e',
      );
      return _modelToEntity(model);
    }
  }
}
