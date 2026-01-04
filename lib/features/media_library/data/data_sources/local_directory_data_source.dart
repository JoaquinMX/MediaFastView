import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/directory_entity.dart';
/// Provides updates while scanning directories for media files.
typedef DirectoryScanProgressCallback =
    void Function(DirectoryScanProgress progress);
    
/// Data source for local directory operations on the file system.
class LocalDirectoryDataSource {
   LocalDirectoryDataSource({
    required this.bookmarkService,
  });

  final BookmarkService bookmarkService;

  static const _scanProgressType = 'progress';
  static const _scanCompleteType = 'complete';
  static const _scanCancelledType = 'cancelled';
  static const _scanCancelMessage = 'cancel';

  

  /// Supported media file extensions for directory scanning
  static const Set<String> _mediaExtensions = {
    // Images
    'jpg', 'jpeg', 'png', 'gif', 'jfif', 'bmp', 'webp',
    // Videos
    'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm',
    // Text
    'txt', 'md', 'log',
  };

  /// System files/directories to exclude
  static const Set<String> _excludedNames = {
    '.', '..',
    '.DS_Store', // macOS
    'Thumbs.db', // Windows
    'desktop.ini', // Windows
    'System Volume Information', // Windows
    '\$RECYCLE.BIN', // Windows
  };

  /// Validates if a directory exists and is accessible.
  /// If the directory has bookmark data, starts accessing the bookmark.
  Future<bool> validateDirectory(DirectoryEntity directory) async {
    String actualPath = directory.path;
    bool startedAccess = false;

    try {
      // Start accessing bookmark if provided
      if (directory.bookmarkData != null && directory.bookmarkData!.isNotEmpty) {
        try {
          final isValid = await bookmarkService.isBookmarkValid(directory.bookmarkData!);
          if (isValid) {
            actualPath = await bookmarkService.startAccessingBookmark(directory.bookmarkData!);
            startedAccess = true;
            LoggingService.instance.info('Successfully started accessing bookmark for directory: ${directory.path}');
          } else {
            LoggingService.instance.warning('Bookmark is invalid for directory: ${directory.path}, falling back to stored path');
          }
        } catch (e) {
          LoggingService.instance.error('Failed to start accessing bookmark for directory ${directory.path}, falling back to stored path, error: $e');
        }
      }

      final dir = Directory(actualPath);
      return await dir.exists();
    } catch (e) {
      LoggingService.instance.error('Error validating directory ${directory.path}: $e');
      return false;
    } finally {
      // Stop accessing bookmark if we started it
      if (startedAccess && directory.bookmarkData != null) {
        try {
          await bookmarkService.stopAccessingBookmark(directory.bookmarkData!);
        } catch (e) {
          LoggingService.instance.warning('Failed to stop accessing bookmark for directory ${directory.path}: $e');
          // Don't throw - cleanup failure shouldn't break validation
        }
      }
    }
  }

  /// Gets directory information from file system.
  Future<DirectoryEntity?> getDirectoryInfo(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return null;
      }

      final stat = await directory.stat();
      final name = path.basename(directoryPath);

      return DirectoryEntity(
        id: _generateId(directoryPath),
        path: directoryPath,
        name: name,
        thumbnailPath: null, // Could be generated from first media file
        tagIds: const [],
        lastModified: stat.modified,
      );
    } catch (e) {
      return null;
    }
  }

  /// Scans a root directory for subdirectories containing media files.
  /// If the directory has bookmark data, starts accessing the bookmark.
  Future<List<DirectoryEntity>> scanDirectoriesWithMedia(
    DirectoryEntity rootDirectory, {
    DirectoryScanProgressCallback? onProgress,
    DirectoryScanCancellationToken? cancellationToken,
  }) async {
    String actualPath = rootDirectory.path;
    bool startedAccess = false;

    try {
      // Start accessing bookmark if provided
      if (rootDirectory.bookmarkData != null && rootDirectory.bookmarkData!.isNotEmpty) {
        try {
          final isValid = await bookmarkService.isBookmarkValid(rootDirectory.bookmarkData!);
          if (isValid) {
            actualPath = await bookmarkService.startAccessingBookmark(rootDirectory.bookmarkData!);
            startedAccess = true;
          } else {
            LoggingService.instance.warning('Bookmark is invalid, using stored path: ${rootDirectory.path}');
          }
        } catch (e) {
          LoggingService.instance.error('Failed to start accessing bookmark, using stored path: ${rootDirectory.path}, error: $e');
        }
      }

      final rootDir = Directory(actualPath);
      if (!await rootDir.exists()) {
        throw DirectoryNotFoundError('Root directory does not exist: $actualPath');
      }

      final directories = await _scanDirectoryInIsolate(
        rootDir.path,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );

      return directories;
    } catch (e) {
      if (e is AppError) {
        rethrow;
      }
      throw DirectoryScanError('Failed to scan directories: $e');
    } finally {
      // Stop accessing bookmark if we started it
      if (startedAccess && rootDirectory.bookmarkData != null) {
        try {
          await bookmarkService.stopAccessingBookmark(rootDirectory.bookmarkData!);
        } catch (e) {
          LoggingService.instance.warning('Failed to stop accessing bookmark for directory ${rootDirectory.path}: $e');
          // Don't throw - cleanup failure shouldn't break scanning
        }
      }
    }
  }

  /// Scans for immediate subdirectories of a given path.
  Future<List<String>> scanSubdirectories(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return [];
      }

      final subdirectories = <String>[];
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);
          if (!_excludedNames.contains(dirName) && !dirName.startsWith('.')) {
            subdirectories.add(entity.path);
          }
        }
      }
      return subdirectories;
    } catch (e) {
      return [];
    }
  }

  /// Generates a unique ID from directory path using a shared hash strategy.
  String _generateId(String directoryPath) {
    return generateDirectoryId(directoryPath);
  }

  Future<List<DirectoryEntity>> _scanDirectoryInIsolate(
    String rootPath, {
    DirectoryScanProgressCallback? onProgress,
    DirectoryScanCancellationToken? cancellationToken,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();

    Isolate? isolate;
    StreamSubscription<dynamic>? receiveSubscription;
    StreamSubscription<dynamic>? errorSubscription;
    final directories = <DirectoryEntity>[];
    final completer = Completer<List<DirectoryEntity>>();
    SendPort? controlPort;

    void handleCompletion(
      Map<dynamic, dynamic> payload, {
      required bool cancelled,
    }) {
      final rawDirectories = (payload['directories'] as List?) ?? const [];
      directories
        ..clear()
        ..addAll(
          rawDirectories
              .whereType<Map<dynamic, dynamic>>()
              .map(_mapPayloadToDirectory),
        );

      final progress = DirectoryScanProgress(
        scannedDirectories: (payload['scanned'] as int?) ?? 0,
        directoriesWithMediaCount: (payload['found'] as int?) ?? directories.length,
        currentPath: payload['currentPath'] as String?,
        directories: List<DirectoryEntity>.from(directories),
        isComplete: true,
        isCancelled: cancelled,
      );

      onProgress?.call(progress);

      if (!completer.isCompleted) {
        completer.complete(List<DirectoryEntity>.from(directories));
      }
    }

    void handleProgress(Map<dynamic, dynamic> payload) {
      final progress = DirectoryScanProgress(
        scannedDirectories: (payload['scanned'] as int?) ?? 0,
        directoriesWithMediaCount: (payload['found'] as int?) ?? 0,
        currentPath: payload['currentPath'] as String?,
      );
      onProgress?.call(progress);
    }

    try {
      isolate = await Isolate.spawn<_DirectoryScanIsolateRequest>(
        _scanDirectoryRecursiveIsolate,
        _DirectoryScanIsolateRequest(
          rootPath: rootPath,
          mediaExtensions: _mediaExtensions.toList(),
          excludedNames: _excludedNames.toList(),
          sendPort: receivePort.sendPort,
        ),
        onError: errorPort.sendPort,
      );

      receiveSubscription = receivePort.listen((message) {
        if (message is SendPort) {
          controlPort = message;
          if (cancellationToken?.isCancelled ?? false) {
            controlPort?.send(_scanCancelMessage);
          }
          cancellationToken?.addListener(() {
            controlPort?.send(_scanCancelMessage);
          });
          return;
        }

        if (message is! Map<dynamic, dynamic>) {
          return;
        }

        final type = message['type'];
        if (type == _scanProgressType) {
          handleProgress(message);
          return;
        }

        if (type == _scanCompleteType) {
          handleCompletion(message, cancelled: false);
          return;
        }

        if (type == _scanCancelledType) {
          handleCompletion(message, cancelled: true);
          return;
        }
      });

      errorSubscription = errorPort.listen((message) {
        if (completer.isCompleted) {
          return;
        }

        completer.completeError(
          DirectoryScanError('Failed to scan directories: $message'),
        );
      });

      final result = await completer.future;
      return result;
    } finally {
      await receiveSubscription?.cancel();
      await errorSubscription?.cancel();
      receivePort.close();
      errorPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  DirectoryEntity _mapPayloadToDirectory(Map<dynamic, dynamic> payload) {
    final pathValue = payload['path'] as String;
    final modifiedEpoch = payload['modified'] as int;
    return DirectoryEntity(
      id: _generateId(pathValue),
      path: pathValue,
      name: payload['name'] as String,
      thumbnailPath: null,
      tagIds: const [],
      lastModified: DateTime.fromMillisecondsSinceEpoch(modifiedEpoch),
    );
  }
}

class DirectoryScanProgress {
  const DirectoryScanProgress({
    required this.scannedDirectories,
    required this.directoriesWithMediaCount,
    this.currentPath,
    this.directories = const <DirectoryEntity>[],
    this.isComplete = false,
    this.isCancelled = false,
  });

  final int scannedDirectories;
  final int directoriesWithMediaCount;
  final String? currentPath;
  final List<DirectoryEntity> directories;
  final bool isComplete;
  final bool isCancelled;
}

typedef _CancelListener = void Function();

class DirectoryScanCancellationToken {
  DirectoryScanCancellationToken();

  bool _isCancelled = false;
  final List<_CancelListener> _listeners = <_CancelListener>[];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    final listenersSnapshot = List<_CancelListener>.from(_listeners);
    for (final listener in listenersSnapshot) {
      listener();
    }
  }

  void addListener(_CancelListener listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(_CancelListener listener) {
    _listeners.remove(listener);
  }
}

class _DirectoryScanIsolateRequest {
  const _DirectoryScanIsolateRequest({
    required this.rootPath,
    required this.mediaExtensions,
    required this.excludedNames,
    required this.sendPort,
  });

  final String rootPath;
  final List<String> mediaExtensions;
  final List<String> excludedNames;
  final SendPort sendPort;
}

Future<void> _scanDirectoryRecursiveIsolate(
  _DirectoryScanIsolateRequest request,
) async {
  final excludedNames = Set<String>.from(request.excludedNames);
  final mediaExtensions = Set<String>.from(request.mediaExtensions);
  final progressPort = request.sendPort;
  final controlPort = ReceivePort();

  progressPort.send(controlPort.sendPort);

  final directoriesWithMedia = <Map<String, Object?>>[];
  final directoriesToVisit = <Directory>[Directory(request.rootPath)];
  var scannedDirectories = 0;
  var cancelled = false;

  controlPort.listen((message) {
    if (message == LocalDirectoryDataSource._scanCancelMessage) {
      cancelled = true;
    }
  });

  while (directoriesToVisit.isNotEmpty && !cancelled) {
    final directory = directoriesToVisit.removeLast();
    scannedDirectories++;

    progressPort.send({
      'type': LocalDirectoryDataSource._scanProgressType,
      'scanned': scannedDirectories,
      'found': directoriesWithMedia.length,
      'currentPath': directory.path,
    });

    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is! Directory) {
          continue;
        }

        final dirName = path.basename(entity.path);

        if (excludedNames.contains(dirName) || dirName.startsWith('.')) {
          continue;
        }

        directoriesToVisit.add(entity);

        if (await _directoryContainsMediaInIsolate(entity, mediaExtensions)) {
          final stat = await entity.stat();
          directoriesWithMedia.add({
            'path': entity.path,
            'name': dirName,
            'modified': stat.modified.millisecondsSinceEpoch,
          });
          progressPort.send({
            'type': LocalDirectoryDataSource._scanProgressType,
            'scanned': scannedDirectories,
            'found': directoriesWithMedia.length,
            'currentPath': entity.path,
          });
        }
      }
    } catch (_) {
      // Ignore directories we cannot access within the isolate to keep scanning.
    }

    if (scannedDirectories % 25 == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  progressPort.send({
    'type': cancelled
        ? LocalDirectoryDataSource._scanCancelledType
        : LocalDirectoryDataSource._scanCompleteType,
    'directories': directoriesWithMedia,
    'scanned': scannedDirectories,
    'found': directoriesWithMedia.length,
  });

  controlPort.close();
}

Future<bool> _directoryContainsMediaInIsolate(
  Directory directory,
  Set<String> mediaExtensions,
) async {
  try {
    await for (final entity in directory.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final extension = path
          .extension(entity.path)
          .toLowerCase()
          .replaceFirst('.', '');

      if (mediaExtensions.contains(extension)) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
