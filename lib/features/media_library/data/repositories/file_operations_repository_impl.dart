import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../domain/entities/file_rename_request.dart';
import '../../domain/entities/trashed_item_entity.dart';
import '../../domain/repositories/file_operations_repository.dart';

/// Implementation of FileOperationsRepository
class FileOperationsRepositoryImpl implements FileOperationsRepository {
  FileOperationsRepositoryImpl(
    this._fileService,
    this._permissionService, [
    LoggingService? logger,
  ])  : _logger = logger ?? LoggingService.instance,
        _uuid = const Uuid();

  final FileService _fileService;
  final PermissionService _permissionService;
  final LoggingService _logger;
  final Uuid _uuid;

  static const _trashFolderName = '.mediafastview_trash';
  static const _trashManifestName = '.manifest.json';

  @override
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    _logger.info('file_operation_delete_file_start', {
      'path': filePath,
    });

    try {
      await _permissionService.runWithBookmarkAccess<void>(
        path: filePath,
        bookmarkData: bookmarkData,
        operation: 'delete_file',
        action: (effectivePath) async {
          await _permissionService.ensurePathAccessible(effectivePath);
          await _fileService.deleteFile(effectivePath);
        },
      );

      _logger.info('file_operation_delete_file_success', {
        'path': filePath,
      });
    } catch (error, stackTrace) {
      _logger.error('file_operation_delete_file_error', {
        'path': filePath,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    _logger.info('file_operation_delete_directory_start', {
      'path': directoryPath,
    });

    try {
      await _permissionService.runWithBookmarkAccess<void>(
        path: directoryPath,
        bookmarkData: bookmarkData,
        operation: 'delete_directory',
        action: (effectivePath) async {
          await _permissionService.ensurePathAccessible(effectivePath);
          await _fileService.deleteDirectory(effectivePath);
        },
      );

      _logger.info('file_operation_delete_directory_success', {
        'path': directoryPath,
      });
    } catch (error, stackTrace) {
      _logger.error('file_operation_delete_directory_error', {
        'path': directoryPath,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<bool> validatePath(String path) async {
    _logger.debug('file_operation_validate_path_start', {
      'path': path,
    });

    await _permissionService.ensureStoragePermission();
    final isAccessible = await _permissionService.canAccessPath(path);

    _logger.debug('file_operation_validate_path_result', {
      'path': path,
      'accessible': isAccessible,
    });

    return isAccessible;
  }

  @override
  String getFileType(String filePath) {
    final type = _fileService.getMediaTypeFromExtension(filePath);
    _logger.debug('file_operation_detect_type', {
      'path': filePath,
      'type': type,
    });
    return type;
  }

  @override
  Future<List<String>> bulkRename(
    List<FileRenameRequest> renameRequests, {
    Map<String, String?>? bookmarkDataMap,
  }) async {
    if (renameRequests.isEmpty) {
      return const [];
    }

    _logger.info('file_operation_bulk_rename_start', {
      'count': renameRequests.length,
    });

    final renamedPaths = <String>[];

    for (final request in renameRequests) {
      final bookmark = bookmarkDataMap?[request.originalPath];
      try {
        final newPath = await _permissionService.runWithBookmarkAccess<String>(
          path: request.originalPath,
          bookmarkData: bookmark,
          operation: 'bulk_rename',
          action: (effectivePath) async {
            final directoryPath = p.dirname(effectivePath);
            await _permissionService.ensurePathAccessible(effectivePath);
            await _permissionService.ensurePathWritable(directoryPath);

            final currentExtension = p.extension(effectivePath);
            final normalizedNewName =
                _resolveNewName(request, currentExtension);
            final destinationPath =
                p.join(directoryPath, normalizedNewName);

            _logger.debug('file_operation_rename_attempt', {
              'source': effectivePath,
              'destination': destinationPath,
            });

            return _fileService.renameEntity(effectivePath, destinationPath);
          },
        );

        renamedPaths.add(newPath);
        _logger.info('file_operation_rename_success', {
          'originalPath': request.originalPath,
          'newPath': newPath,
        });
      } catch (error, stackTrace) {
        _logger.error('file_operation_rename_error', {
          'originalPath': request.originalPath,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
        rethrow;
      }
    }

    return renamedPaths;
  }

  @override
  Future<List<String>> moveToFolder(
    List<String> paths,
    String destinationDirectory, {
    Map<String, String?>? bookmarkDataMap,
    bool createIfMissing = true,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }

    _logger.info('file_operation_move_start', {
      'count': paths.length,
      'destination': destinationDirectory,
    });

    final destinationBookmark = bookmarkDataMap?[destinationDirectory];
    final resolvedDestination = await _permissionService
        .runWithBookmarkAccess<String>(
      path: destinationDirectory,
      bookmarkData: destinationBookmark,
      operation: 'move_to_folder_destination',
      action: (effectiveDestination) async {
        final exists = await _fileService.exists(effectiveDestination);
        if (!exists) {
          if (!createIfMissing) {
            throw DirectoryNotFoundError(
              'Destination directory does not exist: $effectiveDestination',
            );
          }
          await _fileService.ensureDirectoryExists(effectiveDestination);
        } else {
          await _permissionService.ensurePathAccessible(effectiveDestination);
        }

        await _permissionService.ensurePathWritable(effectiveDestination);
        return effectiveDestination;
      },
    );

    final movedPaths = <String>[];

    for (final path in paths) {
      final bookmark = bookmarkDataMap?[path];
      try {
        final movedPath = await _permissionService.runWithBookmarkAccess<String>(
          path: path,
          bookmarkData: bookmark,
          operation: 'move_to_folder',
          action: (effectivePath) async {
            await _permissionService.ensurePathAccessible(effectivePath);
            final targetPath = await _fileService.moveEntityToDirectory(
              effectivePath,
              resolvedDestination,
            );
            return targetPath;
          },
        );

        movedPaths.add(movedPath);
        _logger.info('file_operation_move_success', {
          'source': path,
          'destination': movedPath,
        });
      } catch (error, stackTrace) {
        _logger.error('file_operation_move_error', {
          'source': path,
          'destinationDirectory': destinationDirectory,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
        rethrow;
      }
    }

    return movedPaths;
  }

  @override
  Future<List<TrashedItemEntity>> moveToTrash(
    List<String> paths, {
    Map<String, String?>? bookmarkDataMap,
    String? trashDirectory,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }

    _logger.info('file_operation_trash_start', {
      'count': paths.length,
      'customTrash': trashDirectory,
    });

    final trashedItems = <TrashedItemEntity>[];
    final manifestUpdates = <String, List<TrashedItemEntity>>{};

    for (final path in paths) {
      final bookmark = bookmarkDataMap?[path];
      try {
        final trashedItem = await _permissionService
            .runWithBookmarkAccess<TrashedItemEntity>(
          path: path,
          bookmarkData: bookmark,
          operation: 'move_to_trash',
          action: (effectivePath) async {
            final parentDirectory = p.dirname(effectivePath);
            await _permissionService.ensurePathAccessible(effectivePath);
            await _permissionService.ensurePathWritable(parentDirectory);

            final resolvedTrashDirectory = trashDirectory ??
                p.join(parentDirectory, _trashFolderName);

            await _fileService.ensureDirectoryExists(resolvedTrashDirectory);
            await _permissionService.ensurePathWritable(resolvedTrashDirectory);
            final trashedPath = await _fileService.moveToTrash(
              effectivePath,
              resolvedTrashDirectory,
            );

            final item = TrashedItemEntity(
              id: _uuid.v4(),
              originalPath: effectivePath,
              trashedPath: trashedPath,
              trashedAt: DateTime.now(),
              bookmarkData: bookmark,
            );

            manifestUpdates
                .putIfAbsent(resolvedTrashDirectory, () => [])
                .add(item);

            return item;
          },
        );

        trashedItems.add(trashedItem);
        _logger.info('file_operation_trash_success', {
          'originalPath': path,
          'trashedPath': trashedItem.trashedPath,
        });
      } catch (error, stackTrace) {
        _logger.error('file_operation_trash_error', {
          'path': path,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
        rethrow;
      }
    }

    for (final entry in manifestUpdates.entries) {
      final existing = await _readTrashManifest(entry.key);
      final updated = [...existing, ...entry.value];
      await _writeTrashManifest(entry.key, updated);
    }

    return trashedItems;
  }

  @override
  Future<void> restoreFromTrash(
    List<TrashedItemEntity> items, {
    Map<String, String?>? bookmarkDataMap,
  }) async {
    if (items.isEmpty) {
      return;
    }

    _logger.info('file_operation_restore_start', {
      'count': items.length,
    });

    final manifestRemovals = <String, Set<String>>{};

    for (final item in items) {
      final bookmark =
          bookmarkDataMap?[item.originalPath] ?? item.bookmarkData;
      try {
        await _permissionService.runWithBookmarkAccess<void>(
          path: item.originalPath,
          bookmarkData: bookmark,
          operation: 'restore_from_trash',
          action: (resolvedOriginalPath) async {
            final parentDirectory = p.dirname(resolvedOriginalPath);
            await _fileService.ensureDirectoryExists(parentDirectory);
            await _permissionService.ensurePathWritable(parentDirectory);

            final existsInTrash = await _fileService.exists(item.trashedPath);
            if (!existsInTrash) {
              throw TrashItemNotFoundError(
                'Trashed item missing: ${item.trashedPath}',
              );
            }

            await _permissionService.ensurePathAccessible(item.trashedPath);

            await _fileService.moveEntity(
              item.trashedPath,
              resolvedOriginalPath,
            );

            manifestRemovals
                .putIfAbsent(p.dirname(item.trashedPath), () => <String>{})
                .add(item.id);
          },
        );

        _logger.info('file_operation_restore_success', {
          'originalPath': item.originalPath,
        });
      } catch (error, stackTrace) {
        _logger.error('file_operation_restore_error', {
          'originalPath': item.originalPath,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
        rethrow;
      }
    }

    for (final entry in manifestRemovals.entries) {
      final existing = await _readTrashManifest(entry.key);
      final remaining = existing
          .where((item) => !entry.value.contains(item.id))
          .toList();
      await _writeTrashManifest(entry.key, remaining);
    }
  }

  String _resolveNewName(
    FileRenameRequest request,
    String currentExtension,
  ) {
    if (!request.preserveExtension || currentExtension.isEmpty) {
      return request.newName;
    }

    if (request.newName.toLowerCase().endsWith(
          currentExtension.toLowerCase(),
        )) {
      return request.newName;
    }

    return '${request.newName}$currentExtension';
  }

  Future<List<TrashedItemEntity>> _readTrashManifest(String trashDirectory) async {
    final manifestFile = File(_manifestPath(trashDirectory));
    if (!await manifestFile.exists()) {
      return [];
    }

    try {
      final raw = await manifestFile.readAsString();
      if (raw.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => TrashedItemEntity.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ))
          .toList();
    } catch (error) {
      _logger.warning('file_operation_trash_manifest_read_error', {
        'trashDirectory': trashDirectory,
        'error': error.toString(),
      });
      return [];
    }
  }

  Future<void> _writeTrashManifest(
    String trashDirectory,
    List<TrashedItemEntity> items,
  ) async {
    await _fileService.ensureDirectoryExists(trashDirectory);
    final manifestFile = File(_manifestPath(trashDirectory));
    final payload = jsonEncode(
      items.map((item) => item.toJson()).toList(),
    );

    await manifestFile.writeAsString(payload, flush: true);

    _logger.debug('file_operation_trash_manifest_written', {
      'trashDirectory': trashDirectory,
      'entries': items.length,
    });
  }

  String _manifestPath(String trashDirectory) {
    return p.join(trashDirectory, _trashManifestName);
  }
}
