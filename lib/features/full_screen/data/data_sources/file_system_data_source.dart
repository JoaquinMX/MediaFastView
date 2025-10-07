import 'dart:io';

import '../../../../core/error/app_error.dart';
import '../../../../core/utils/retry_utils.dart';

/// Data source for file system operations in full-screen viewing
abstract class FileSystemDataSource {
  /// Check if file exists at path
  Future<bool> fileExists(String path);

  /// Get file size
  Future<int> getFileSize(String path);

  /// Get file last modified date
  Future<DateTime> getFileLastModified(String path);

  /// Read file as bytes (for thumbnails or small files)
  Future<List<int>> readFileAsBytes(String path);
}

/// Implementation of FileSystemDataSource
class FileSystemDataSourceImpl implements FileSystemDataSource {
  @override
  Future<bool> fileExists(String path) async {
    return await RetryUtils.retryWithBackoff(
      () => File(path).exists(),
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    );
  }

  @override
  Future<int> getFileSize(String path) async {
    return await RetryUtils.retryWithBackoff(
      () => File(path).length(),
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('no such file')) {
        throw FileNotFoundError('File not found: $path');
      } else if (errorString.contains('permission denied')) {
        throw FileAccessDeniedError('Permission denied accessing file: $path');
      } else {
        throw FileReadError('Failed to get file size for $path: $error');
      }
    });
  }

  @override
  Future<DateTime> getFileLastModified(String path) async {
    return await RetryUtils.retryWithBackoff(
      () => File(path).lastModified(),
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('no such file')) {
        throw FileNotFoundError('File not found: $path');
      } else if (errorString.contains('permission denied')) {
        throw FileAccessDeniedError('Permission denied accessing file: $path');
      } else {
        throw FileReadError('Failed to get file modification time for $path: $error');
      }
    });
  }

  @override
  Future<List<int>> readFileAsBytes(String path) async {
    return await RetryUtils.retryWithBackoff(
      () => File(path).readAsBytes(),
      shouldRetry: RetryUtils.shouldRetryFileOperation,
    ).catchError((error) {
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('no such file')) {
        throw FileNotFoundError('File not found: $path');
      } else if (errorString.contains('permission denied')) {
        throw FileAccessDeniedError('Permission denied reading file: $path');
      } else {
        throw FileReadError('Failed to read file $path: $error');
      }
    });
  }
}
