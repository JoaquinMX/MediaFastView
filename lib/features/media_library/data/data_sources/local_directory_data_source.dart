import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../domain/entities/directory_entity.dart';

/// Data source for local directory operations on the file system.
class LocalDirectoryDataSource {
  const LocalDirectoryDataSource({
    required this.bookmarkService,
  });

  final BookmarkService bookmarkService;

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
  Future<List<DirectoryEntity>> scanDirectoriesWithMedia(DirectoryEntity rootDirectory) async {
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

      final directories = <DirectoryEntity>[];
      await _scanDirectoryRecursive(rootDir, directories);
      return directories;
    } catch (e) {
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

  /// Recursively scans directories for those containing media files.
  Future<void> _scanDirectoryRecursive(
    Directory directory,
    List<DirectoryEntity> directories,
  ) async {
    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);

          // Skip excluded directories
          if (_excludedNames.contains(dirName) || dirName.startsWith('.')) {
            continue;
          }

          // Check if this directory contains media files
          if (await _directoryContainsMedia(entity)) {
            final stat = await entity.stat();
            final dirEntity = DirectoryEntity(
              id: _generateId(entity.path),
              path: entity.path,
              name: dirName,
              thumbnailPath: null,
              tagIds: const [],
              lastModified: stat.modified,
            );
            directories.add(dirEntity);
          }

          // Recursively scan subdirectories
          await _scanDirectoryRecursive(entity, directories);
        }
      }
    } catch (e) {
      // Log permission errors for debugging
      LoggingService.instance.error('Failed to scan directory ${directory.path}: $e');
      if (e.toString().contains('Operation not permitted') || e.toString().contains('errno = 1')) {
        LoggingService.instance.warning('Permission denied - security-scoped bookmark may have expired');
      }
      // Skip directories we can't access
      return;
    }
  }

  /// Checks if a directory contains any media files.
  Future<bool> _directoryContainsMedia(Directory directory) async {
    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          final extension = path
              .extension(entity.path)
              .toLowerCase()
              .replaceFirst('.', '');

          if (_mediaExtensions.contains(extension)) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
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

  /// Generates a unique ID from directory path using hash.
  String _generateId(String directoryPath) {
    return directoryPath.hashCode.toString();
  }
}
