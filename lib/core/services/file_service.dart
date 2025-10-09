import 'dart:io';
import 'package:path/path.dart' as path;

import '../error/app_error.dart';
import '../utils/retry_utils.dart';
import '../../features/media_library/data/format/media_format_registry.dart';
import '../../features/media_library/domain/entities/media_entity.dart';

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
    final mediaType = MediaFormatRegistry.mediaTypeForExtension(extension);
    switch (mediaType) {
      case MediaType.image:
        return 'image';
      case MediaType.video:
        return 'video';
      case MediaType.text:
        return 'text';
      case MediaType.audio:
        return 'audio';
      case MediaType.document:
        return 'document';
      case MediaType.directory:
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
}
