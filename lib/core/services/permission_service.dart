import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../config/app_config.dart';
import '../error/app_error.dart';
import 'bookmark_service.dart';
import 'logging_service.dart';

/// Enum representing the status of directory access permissions
enum PermissionStatus {
  granted,
  denied,
  notFound,
  error,
}

/// Result of bookmark validation
class BookmarkValidationResult {
  const BookmarkValidationResult({
    required this.isValid,
    this.resolvedPath,
    this.reason,
    this.renewedBookmarkData,
  });

  final bool isValid;
  final String? resolvedPath;
  final String? reason;
  final String? renewedBookmarkData;
}

/// Result of directory access recovery
class DirectoryRecoveryResult {
  const DirectoryRecoveryResult({
    required this.directoryPath,
    this.bookmarkData,
  });

  final String directoryPath;
  final String? bookmarkData;
}

/// Service for handling permissions on iOS/macOS
class PermissionService {
  PermissionService([BookmarkService? bookmarkService])
      : _bookmarkService = bookmarkService ?? BookmarkService.instance;

  final BookmarkService _bookmarkService;

  /// Checks if storage permission is granted
  Future<bool> hasStoragePermission() async {
    // On iOS/macOS, file access is more granular and doesn't require explicit permission
    // We check by attempting to access a known directory
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final testFile = File('$homeDir${AppConfig.permissionTestFileName}');
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Requests storage permission
  Future<bool> requestStoragePermission() async {
    // On iOS/macOS, permissions are handled by the system
    // We can't request them programmatically in the same way
    return await hasStoragePermission();
  }

  /// Checks if we can access a specific directory path (macOS specific)
  Future<PermissionStatus> checkDirectoryAccess(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return PermissionStatus.notFound;
      }

      // Try to list directory contents to check access
      await directory.list().first;
      return PermissionStatus.granted;
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Operation not permitted') ||
          errorMessage.contains('errno = 1') ||
          errorMessage.contains('Permission denied')) {
        return PermissionStatus.denied;
      }
      return PermissionStatus.error;
    }
  }

  /// Validates bookmark data for macOS security-scoped access
  Future<BookmarkValidationResult> validateBookmark(String bookmarkData) async {
    try {
      if (!Platform.isMacOS) {
        return const BookmarkValidationResult(
          isValid: false,
          reason: 'Bookmarks only supported on macOS',
        );
      }

      logPermissionEvent('bookmark_validation_start', details: 'validating bookmark');

      // Check if bookmark is valid
      final isValid = await _bookmarkService.isBookmarkValid(bookmarkData);

      if (!isValid) {
        logPermissionEvent('bookmark_validation_failed', error: 'CRITICAL: bookmark invalid or expired - this is the root cause of access denied errors');
        LoggingService.instance.error('CRITICAL: Bookmark validation failed in PermissionService - bookmark has expired or become invalid');
        return const BookmarkValidationResult(
          isValid: false,
          reason: 'Bookmark is invalid or expired',
        );
      }

      // Try to resolve the bookmark to get the current path
      try {
        final resolvedPath = await _bookmarkService.resolveBookmark(bookmarkData);
        logPermissionEvent('bookmark_validation_success', details: 'resolved path: $resolvedPath');
        return BookmarkValidationResult(
          isValid: true,
          resolvedPath: resolvedPath,
        );
      } catch (resolveError) {
        logPermissionEvent('bookmark_resolution_failed', error: resolveError.toString());
        return const BookmarkValidationResult(
          isValid: false,
          reason: 'Bookmark valid but resolution failed',
        );
      }
    } catch (e) {
      logPermissionEvent('bookmark_validation_error', error: e.toString());
      return BookmarkValidationResult(
        isValid: false,
        reason: 'Validation failed: $e',
      );
    }
  }

  /// Attempts to recover access to a directory by prompting user
  Future<DirectoryRecoveryResult?> recoverDirectoryAccess(String directoryPath) async {
    try {
      logPermissionEvent('directory_access_recovery_start', path: directoryPath);

      if (!Platform.isMacOS) {
        // Fallback to file picker for non-macOS platforms
        final selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Re-select Directory for Access Recovery',
          initialDirectory: directoryPath,
        );

        if (selectedDirectory == null) {
          logPermissionEvent('directory_access_recovery_cancelled', path: directoryPath);
          return null;
        }

        // Validate that the selected directory is accessible
        final accessStatus = await checkDirectoryAccess(selectedDirectory);
        if (accessStatus != PermissionStatus.granted) {
          logPermissionEvent(
            'directory_access_recovery_failed',
            path: selectedDirectory,
            error: 'Selected directory not accessible: $accessStatus',
          );
          return null;
        }

        logPermissionEvent(
          'directory_access_recovery_success',
          path: selectedDirectory,
          details: 'original: $directoryPath',
        );

        return DirectoryRecoveryResult(directoryPath: selectedDirectory);
      }

      // On macOS, use the new bookmark-based approach
      final result = await _bookmarkService.selectDirectoryAndCreateBookmark(
        initialDirectoryPath: directoryPath,
      );

      final selectedPath = result['directoryPath'] as String?;
      final bookmarkData = result['bookmarkData'] as String?;

      if (selectedPath == null) {
        logPermissionEvent('directory_access_recovery_cancelled', path: directoryPath);
        return null;
      }

      logPermissionEvent(
        'directory_access_recovery_success',
        path: selectedPath,
        details: 'original: $directoryPath, bookmark_created: true',
      );

      return DirectoryRecoveryResult(
        directoryPath: selectedPath,
        bookmarkData: bookmarkData,
      );
    } catch (e) {
      logPermissionEvent(
        'directory_access_recovery_error',
        path: directoryPath,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Attempts to renew an expired bookmark by re-creating it
  Future<String?> renewBookmark(String expiredBookmarkData, String directoryPath) async {
    try {
      if (!Platform.isMacOS) {
        return null;
      }

      logPermissionEvent('bookmark_renewal_start', path: directoryPath);

      // First try to recover access by prompting user to re-select directory
      final recoveryResult = await recoverDirectoryAccess(directoryPath);
      if (recoveryResult == null) {
        logPermissionEvent('bookmark_renewal_cancelled', path: directoryPath);
        return null;
      }

      // Use the bookmark data from recovery if available, otherwise create new one
      final newBookmarkData = recoveryResult.bookmarkData ?? await _bookmarkService.createBookmark(recoveryResult.directoryPath);

      logPermissionEvent(
        'bookmark_renewal_success',
        path: recoveryResult.directoryPath,
        details: 'old bookmark renewed',
      );

      return newBookmarkData;
    } catch (e) {
      logPermissionEvent(
        'bookmark_renewal_error',
        path: directoryPath,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Validates bookmark and attempts renewal if expired
  Future<BookmarkValidationResult> validateAndRenewBookmark(
    String bookmarkData,
    String directoryPath,
  ) async {
    final validationResult = await validateBookmark(bookmarkData);

    if (validationResult.isValid) {
      return validationResult;
    }

    // Bookmark is invalid, try to renew it
    logPermissionEvent(
      'bookmark_auto_renewal_attempt',
      path: directoryPath,
      details: 'reason: ${validationResult.reason}',
    );

    final renewedBookmark = await renewBookmark(bookmarkData, directoryPath);
    if (renewedBookmark != null) {
      // Validate the new bookmark
      final renewedValidation = await validateBookmark(renewedBookmark);
      if (renewedValidation.isValid) {
        return BookmarkValidationResult(
          isValid: true,
          resolvedPath: renewedValidation.resolvedPath,
          reason: 'Bookmark renewed successfully',
          renewedBookmarkData: renewedBookmark,
        );
      }
    }

    return validationResult; // Return original validation result if renewal failed
  }

  /// Logs permission-related events for debugging
  void logPermissionEvent(String event, {String? path, String? error, String? details}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[PermissionService:$timestamp] $event';
    final additionalInfo = <String>[];
    if (path != null) additionalInfo.add('path=$path');
    if (error != null) additionalInfo.add('error=$error');
    if (details != null) additionalInfo.add('details=$details');

    final fullMessage = additionalInfo.isEmpty ? logMessage : '$logMessage (${additionalInfo.join(', ')})';

    // Use the logging service
    LoggingService.instance.info(fullMessage);
  }

  /// Checks if we can access a specific path
  Future<bool> canAccessPath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        // Try to read file stats
        await file.stat();
        return true;
      }

      final directory = Directory(path);
      if (await directory.exists()) {
        // Try to list directory contents
        await directory.list().first;
        return true;
      }

      // Path doesn't exist, check if parent directory is accessible
      final parent = File(path).parent;
      if (await parent.exists()) {
        await parent.list().first;
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if we can write to a specific path
  Future<bool> canWriteToPath(String path) async {
    try {
      final testFile = File('$path${AppConfig.writeTestFileName}');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Throws an error if storage permission is not granted
  Future<void> ensureStoragePermission() async {
    final hasPermission = await hasStoragePermission();
    if (!hasPermission) {
      throw PermissionError(
        'Storage permission is required for file operations',
      );
    }
  }

  /// Throws an error if path is not accessible
  Future<void> ensurePathAccessible(String path) async {
    final accessible = await canAccessPath(path);
    if (!accessible) {
      throw PermissionError('Cannot access path: $path');
    }
  }

  /// Throws an error if path is not writable
  Future<void> ensurePathWritable(String path) async {
    final writable = await canWriteToPath(path);
    if (!writable) {
      throw PermissionError('Cannot write to path: $path');
    }
  }

  /// Wraps a file system operation with optional security-scoped bookmark access.
  Future<T> runWithBookmarkAccess<T>({
    required String path,
    String? bookmarkData,
    required Future<T> Function(String effectivePath) action,
    String operation = 'filesystem_operation',
  }) async {
    await ensureStoragePermission();

    if (bookmarkData == null) {
      logPermissionEvent(
        '${operation}_without_bookmark',
        path: path,
        details: 'bookmark=absent',
      );
      return action(path);
    }

    logPermissionEvent(
      '${operation}_bookmark_start',
      path: path,
    );

    String? scopedPath;
    try {
      scopedPath = await _bookmarkService.startAccessingBookmark(bookmarkData);
      logPermissionEvent(
        '${operation}_bookmark_granted',
        path: scopedPath,
      );
      return await action(scopedPath);
    } catch (error) {
      logPermissionEvent(
        '${operation}_bookmark_error',
        path: path,
        error: error.toString(),
      );
      rethrow;
    } finally {
      if (scopedPath != null) {
        try {
          await _bookmarkService.stopAccessingBookmark(bookmarkData);
          logPermissionEvent(
            '${operation}_bookmark_released',
            path: scopedPath,
          );
        } catch (error) {
          logPermissionEvent(
            '${operation}_bookmark_release_error',
            path: scopedPath,
            error: error.toString(),
          );
        }
      }
    }
  }

  /// Monitors permission status for a directory and triggers recovery if needed
  Future<PermissionMonitorResult> monitorDirectoryPermissions(
    String directoryPath, {
    String? bookmarkData,
    Duration checkInterval = const Duration(minutes: 5),
  }) async {
    logPermissionEvent(
      'monitor_start',
      path: directoryPath,
      details: 'interval=${checkInterval.inMinutes}min',
    );

    final accessStatus = await checkDirectoryAccess(directoryPath);

    // If no bookmark data, just check directory access
    if (bookmarkData == null) {
      final requiresRecovery = accessStatus != PermissionStatus.granted;
      return PermissionMonitorResult(
        status: accessStatus,
        requiresRecovery: requiresRecovery,
        reason: requiresRecovery ? 'Directory access denied' : null,
        lastChecked: DateTime.now(),
      );
    }

    // Validate bookmark and attempt renewal if needed
    final bookmarkValidation = await validateAndRenewBookmark(bookmarkData, directoryPath);

    final bookmarkValid = bookmarkValidation.isValid;
    final requiresRecovery = accessStatus == PermissionStatus.denied || !bookmarkValid;

    if (requiresRecovery) {
      final reason = accessStatus == PermissionStatus.denied
          ? 'Directory access denied'
          : 'Bookmark invalid: ${bookmarkValidation.reason}';
      logPermissionEvent(
        'monitor_recovery_needed',
        path: directoryPath,
        error: reason,
      );

      return PermissionMonitorResult(
        status: PermissionStatus.denied,
        requiresRecovery: true,
        reason: reason,
        lastChecked: DateTime.now(),
      );
    }

    return PermissionMonitorResult(
      status: accessStatus,
      requiresRecovery: false,
      reason: null,
      lastChecked: DateTime.now(),
    );
  }

  /// Validates multiple directories and returns recovery recommendations
  Future<List<DirectoryPermissionStatus>> validateMultipleDirectories(
    List<String> directoryPaths, {
    Map<String, String?>? bookmarkDataMap,
  }) async {
    final results = <DirectoryPermissionStatus>[];

    for (final path in directoryPaths) {
      final bookmarkData = bookmarkDataMap?[path];
      final accessStatus = await checkDirectoryAccess(path);

      // If no bookmark data, just check directory access
      if (bookmarkData == null) {
        final requiresRecovery = accessStatus != PermissionStatus.granted;
        results.add(DirectoryPermissionStatus(
          path: path,
          status: accessStatus,
          requiresRecovery: requiresRecovery,
          reason: requiresRecovery ? 'Directory access denied' : null,
          lastChecked: DateTime.now(),
        ));

        logPermissionEvent(
          'batch_validation',
          path: path,
          details: 'status=$accessStatus, recovery_needed=$requiresRecovery',
        );
        continue;
      }

      // Validate bookmark and attempt renewal if needed
      final bookmarkValidation = await validateAndRenewBookmark(bookmarkData, path);
      final bookmarkValid = bookmarkValidation.isValid;

      final requiresRecovery = accessStatus == PermissionStatus.denied || !bookmarkValid;

      final reason = accessStatus == PermissionStatus.denied
          ? 'Directory access denied'
          : !bookmarkValid
              ? 'Bookmark invalid: ${bookmarkValidation.reason}'
              : null;

      results.add(DirectoryPermissionStatus(
        path: path,
        status: accessStatus,
        requiresRecovery: requiresRecovery,
        reason: reason,
        lastChecked: DateTime.now(),
      ));

      logPermissionEvent(
        'batch_validation',
        path: path,
        details: 'status=$accessStatus, bookmark_valid=$bookmarkValid, recovery_needed=$requiresRecovery',
      );
    }

    return results;
  }
}

/// Result of permission monitoring
class PermissionMonitorResult {
  const PermissionMonitorResult({
    required this.status,
    required this.requiresRecovery,
    this.reason,
    required this.lastChecked,
  });

  final PermissionStatus status;
  final bool requiresRecovery;
  final String? reason;
  final DateTime lastChecked;
}

/// Status of a directory's permissions
class DirectoryPermissionStatus {
  const DirectoryPermissionStatus({
    required this.path,
    required this.status,
    required this.requiresRecovery,
    this.reason,
    required this.lastChecked,
  });

  final String path;
  final PermissionStatus status;
  final bool requiresRecovery;
  final String? reason;
  final DateTime lastChecked;
}
