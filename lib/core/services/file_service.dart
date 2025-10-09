import 'dart:io';
import 'package:path/path.dart' as path;

import '../error/app_error.dart';
import '../utils/retry_utils.dart';

/// Service for handling file system operations
class FileService {
  /// Deletes a file at the given path
  Future<void> deleteFile(String filePath) async {
    await RetryUtils.retryWithBackoff(
      () async {
        final file = File(filePath);
        if (!await file.exists()) {
          throw FileNotFoundError('File does not exist: $filePath');
        }
        await file.delete();
      },
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      if (error is FileNotFoundError) {
        throw error;
      }
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') || errorString.contains('operation not permitted')) {
        throw FileAccessDeniedError('Permission denied deleting file: $filePath');
      } else if (errorString.contains('no such file')) {
        throw FileNotFoundError('File not found: $filePath');
      } else {
        throw FileDeleteError('Failed to delete file $filePath: $error');
      }
    });
  }

  /// Deletes a directory and all its contents recursively
  Future<void> deleteDirectory(String directoryPath) async {
    await RetryUtils.retryWithBackoff(
      () async {
        final directory = Directory(directoryPath);
        if (!await directory.exists()) {
          throw DirectoryNotFoundError('Directory does not exist: $directoryPath');
        }
        await directory.delete(recursive: true);
      },
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      if (error is DirectoryNotFoundError) {
        throw error;
      }
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') || errorString.contains('operation not permitted')) {
        throw DirectoryAccessDeniedError('Permission denied deleting directory: $directoryPath');
      } else if (errorString.contains('no such file') || errorString.contains('directory not found')) {
        throw DirectoryNotFoundError('Directory not found: $directoryPath');
      } else {
        throw DirectoryError('Failed to delete directory $directoryPath: $error');
      }
    });
  }

  /// Ensures a directory exists, creating it if necessary
  Future<Directory> ensureDirectoryExists(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Checks if a file or directory exists
  Future<bool> exists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  /// Gets file information
  Future<FileStat> getFileStat(String filePath) async {
    return await RetryUtils.retryWithBackoff(
      () => File(filePath).stat(),
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') || errorString.contains('operation not permitted')) {
        throw FileAccessDeniedError('Permission denied accessing file: $filePath');
      } else if (errorString.contains('no such file')) {
        throw FileNotFoundError('File not found: $filePath');
      } else {
        throw FileReadError('Failed to get file info for $filePath: $error');
      }
    });
  }

  /// Gets directory contents
  Future<List<FileSystemEntity>> getDirectoryContents(
    String directoryPath,
  ) async {
    return await RetryUtils.retryWithBackoff(
      () async {
        final directory = Directory(directoryPath);
        if (!await directory.exists()) {
          throw DirectoryNotFoundError('Directory does not exist: $directoryPath');
        }
        return await directory.list().toList();
      },
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      if (error is DirectoryNotFoundError) {
        throw error;
      }
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') || errorString.contains('operation not permitted')) {
        throw DirectoryAccessDeniedError('Permission denied accessing directory: $directoryPath');
      } else {
        throw DirectoryScanError('Failed to read directory $directoryPath: $error');
      }
    });
  }

  /// Validates if a path is accessible
  Future<bool> isPathAccessible(String path) async {
    try {
      await File(path).stat();
      return true;
    } on FileSystemException {
      try {
        await Directory(path).stat();
        return true;
      } on FileSystemException {
        return false;
      }
    }
  }

  /// Gets file extension from path
  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Determines media type from file extension
  String getMediaTypeFromExtension(String filePath) {
    final extension = getFileExtension(filePath);

    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.tiff':
      case '.tif':
        return 'image';
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.mkv':
      case '.wmv':
      case '.flv':
      case '.webm':
        return 'video';
      case '.txt':
      case '.md':
      case '.json':
      case '.xml':
      case '.html':
      case '.css':
      case '.js':
      case '.dart':
        return 'text';
      default:
        return 'unknown';
    }
  }

  /// Checks if path is a directory
  Future<bool> isDirectory(String path) async {
    return await Directory(path).exists();
  }

  /// Gets directory size recursively
  Future<int> getDirectorySize(String directoryPath) async {
    return await RetryUtils.retryWithBackoff(
      () async {
        final directory = Directory(directoryPath);
        if (!await directory.exists()) {
          throw DirectoryNotFoundError('Directory does not exist: $directoryPath');
        }

        int totalSize = 0;
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
        return totalSize;
      },
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      if (error is DirectoryNotFoundError) {
        throw error;
      }
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') || errorString.contains('operation not permitted')) {
        throw DirectoryAccessDeniedError('Permission denied accessing directory: $directoryPath');
      } else {
        throw DirectoryScanError('Failed to calculate directory size for $directoryPath: $error');
      }
    });
  }

  /// Renames a file system entity
  Future<String> renameEntity(String sourcePath, String destinationPath) async {
    return _relocateEntity(
      sourcePath,
      destinationPath,
      (source, destination, reason) {
        if (reason == 'destination_exists') {
          return FileRenameError(
            'Cannot rename $source because $destination already exists',
          );
        }
        return FileRenameError('Failed to rename $source to $destination');
      },
    );
  }

  /// Moves a file system entity to a specific destination path
  Future<String> moveEntity(String sourcePath, String destinationPath) async {
    return _relocateEntity(
      sourcePath,
      destinationPath,
      (source, destination, reason) {
        if (reason == 'destination_exists') {
          return FileMoveError(
            'Cannot move $source because $destination already exists',
          );
        }
        return FileMoveError('Failed to move $source to $destination');
      },
    );
  }

  /// Moves a file system entity into the destination directory, preserving the
  /// original name and ensuring no conflicts.
  Future<String> moveEntityToDirectory(
    String sourcePath,
    String destinationDirectory,
  ) async {
    final baseName = path.basename(sourcePath);
    final destinationPath =
        await _resolveUniqueDestination(destinationDirectory, baseName);
    return moveEntity(sourcePath, destinationPath);
  }

  /// Moves a file system entity into the trash directory and returns the
  /// resulting trashed path.
  Future<String> moveToTrash(String sourcePath, String trashDirectory) async {
    await ensureDirectoryExists(trashDirectory);
    final trashedName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(sourcePath)}';
    final destinationPath =
        await _resolveUniqueDestination(trashDirectory, trashedName);
    return moveEntity(sourcePath, destinationPath);
  }

  Future<String> _relocateEntity(
    String sourcePath,
    String destinationPath,
    FileSystemError Function(
      String source,
      String destination,
      String reason,
    )
        errorBuilder,
  ) async {
    return await RetryUtils.retryWithBackoff(
      () async {
        final entityType = await FileSystemEntity.type(sourcePath);
        if (entityType == FileSystemEntityType.notFound) {
          throw FileNotFoundError('Source does not exist: $sourcePath');
        }

        final destinationDirectory =
            Directory(path.dirname(destinationPath));
        if (!await destinationDirectory.exists()) {
          await destinationDirectory.create(recursive: true);
        }

        if (await exists(destinationPath)) {
          throw errorBuilder(
            sourcePath,
            destinationPath,
            'destination_exists',
          );
        }

        if (entityType == FileSystemEntityType.directory) {
          await Directory(sourcePath).rename(destinationPath);
        } else {
          await File(sourcePath).rename(destinationPath);
        }

        return destinationPath;
      },
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      if (error is FileSystemError) {
        throw error;
      }

      final errorString = error.toString().toLowerCase();
      if (errorString.contains('permission denied') ||
          errorString.contains('operation not permitted')) {
        throw FileAccessDeniedError(
          'Permission denied relocating $sourcePath to $destinationPath',
        );
      }

      throw errorBuilder(sourcePath, destinationPath, 'operation_failed');
    });
  }

  Future<String> _resolveUniqueDestination(
    String directoryPath,
    String fileName,
  ) async {
    await ensureDirectoryExists(directoryPath);

    var candidate = path.join(directoryPath, fileName);
    if (!await exists(candidate)) {
      return candidate;
    }

    final extension = path.extension(fileName);
    final baseName = extension.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - extension.length);

    var counter = 1;
    while (true) {
      final suffix = '($counter)';
      final candidateName = extension.isEmpty
          ? '$baseName$suffix'
          : '$baseName$suffix$extension';
      candidate = path.join(directoryPath, candidateName);
      if (!await exists(candidate)) {
        return candidate;
      }
      counter++;
    }
  }
}
