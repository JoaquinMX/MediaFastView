import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/logging_service.dart';
import '../models/media_model.dart';
import '../../domain/entities/media_entity.dart';
import '../isar/isar_media_data_source.dart';

/// Result of permission validation for directory access
class PermissionValidationResult {
  const PermissionValidationResult({
    required this.canAccess,
    required this.requiresRecovery,
    this.reason,
    this.renewedBookmarkData,
  });

  final bool canAccess;
  final bool requiresRecovery;
  final String? reason;
  final String? renewedBookmarkData;
}

/// Data source for scanning media files from the filesystem.
class FilesystemMediaDataSource {
  const FilesystemMediaDataSource(this._bookmarkService, [this._permissionService]);

  final BookmarkService _bookmarkService;
  final PermissionService? _permissionService;

  /// Gets the permission service, creating one if not provided
  PermissionService get _permissionSvc => _permissionService ?? PermissionService();

  /// Supported image file extensions
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'jfif',
    'bmp',
    'webp',
  };

  /// Supported video file extensions
  static const Set<String> _videoExtensions = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'webm',
  };

  /// Supported text file extensions
  static const Set<String> _textExtensions = {'txt', 'md', 'log'};

  /// System files to exclude (macOS specific)
  static const Set<String> _excludedFiles = {
    '._', // macOS resource fork files
    '.DS_Store', // macOS directory metadata
    'Thumbs.db', // Windows thumbnail cache
    'desktop.ini', // Windows desktop.ini
  };

  /// Validates permissions for directory access before scanning
  Future<PermissionValidationResult> validateDirectoryAccess(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    _permissionSvc.logPermissionEvent(
      'validate_directory_access',
      path: directoryPath,
      details: 'bookmark_present=${bookmarkData != null}',
    );

    // First check if bookmark is valid if provided
    if (bookmarkData != null && bookmarkData.isNotEmpty) {
      final bookmarkResult = await _permissionSvc.validateBookmark(bookmarkData);
      if (!bookmarkResult.isValid) {
        _permissionSvc.logPermissionEvent(
          'bookmark_validation_failed_attempting_renewal',
          path: directoryPath,
          error: bookmarkResult.reason,
        );

        // Attempt to renew the bookmark
        final renewedBookmark = await _permissionSvc.renewBookmark(bookmarkData, directoryPath);
        if (renewedBookmark != null) {
          _permissionSvc.logPermissionEvent(
            'bookmark_renewal_success_in_validation',
            path: directoryPath,
          );
          // Validate the renewed bookmark
          final renewedValidation = await _permissionSvc.validateBookmark(renewedBookmark);
          if (renewedValidation.isValid) {
            // Check directory access with renewed bookmark
            final accessStatus = await _permissionSvc.checkDirectoryAccess(directoryPath);
            final canAccess = accessStatus == PermissionStatus.granted;
            return PermissionValidationResult(
              canAccess: canAccess,
              requiresRecovery: !canAccess,
              reason: canAccess ? null : 'Access ${accessStatus.name} after renewal',
              renewedBookmarkData: renewedBookmark,
            );
          }
        }

        // Renewal failed, require recovery
        return PermissionValidationResult(
          canAccess: false,
          requiresRecovery: true,
          reason: 'Invalid bookmark and renewal failed: ${bookmarkResult.reason}',
        );
      }
    }

    // Check directory access
    final accessStatus = await _permissionSvc.checkDirectoryAccess(directoryPath);
    final canAccess = accessStatus == PermissionStatus.granted;

    _permissionSvc.logPermissionEvent(
      'directory_access_check',
      path: directoryPath,
      details: 'status=$accessStatus',
    );

    return PermissionValidationResult(
      canAccess: canAccess,
      requiresRecovery: !canAccess && accessStatus == PermissionStatus.denied,
      reason: canAccess ? null : 'Access ${accessStatus.name}',
    );
  }

  /// Scans a directory for media files and subdirectories.
   Future<List<MediaModel>> scanMediaForDirectory(
     String directoryPath,
     String directoryId, {
     String? bookmarkData,
   }) async {
     final scanStartTime = DateTime.now();
     _permissionSvc.logPermissionEvent(
       'scan_media_start',
       path: directoryPath,
       details: 'directoryId=$directoryId, bookmark_present=${bookmarkData != null}',
     );

     // Validate permissions proactively
     final validationResult = await validateDirectoryAccess(directoryPath, bookmarkData: bookmarkData);
     if (!validationResult.canAccess) {
       _permissionSvc.logPermissionEvent(
         'scan_cancelled_permission_denied',
         path: directoryPath,
         error: validationResult.reason,
       );
       throw DirectoryAccessDeniedError('Permission denied: ${validationResult.reason}');
     }

     // Use renewed bookmark data if available
     final effectiveBookmarkData = validationResult.renewedBookmarkData ?? bookmarkData;

     LoggingService.instance.info('Starting scan for directory: $directoryPath, bookmarkData present: ${effectiveBookmarkData != null && effectiveBookmarkData.isNotEmpty}');
     String resolvedPath = directoryPath;
     bool startedAccess = false;
     try {
       // Start accessing bookmark if provided
       if (effectiveBookmarkData != null && effectiveBookmarkData.isNotEmpty) {
         LoggingService.instance.debug('Bookmark data provided, checking validity...');
         try {
           final isValid = await _bookmarkService.isBookmarkValid(effectiveBookmarkData);
           LoggingService.instance.debug('Bookmark validity check result: $isValid');
           if (isValid) {
             resolvedPath = await _bookmarkService.startAccessingBookmark(effectiveBookmarkData);
             startedAccess = true;
             LoggingService.instance.info('Started accessing bookmark for directory: $directoryPath -> $resolvedPath');
           } else {
             LoggingService.instance.error('CRITICAL: Bookmark validation failed during scan for directory: $directoryPath - bookmark has expired. Falling back to stored path: $directoryPath');
             // Don't throw here - let the directory access check below handle it
           }
         } catch (e) {
           LoggingService.instance.error('Failed to start accessing bookmark for directory $directoryPath: $e');
           // Fall back to original path
         }
       } else {
         LoggingService.instance.debug('No bookmark data provided, using original path: $directoryPath');
       }

       final directory = Directory(resolvedPath);
       LoggingService.instance.debug('Checking if directory exists: $resolvedPath');
       if (!await directory.exists()) {
         LoggingService.instance.error('CRITICAL: Directory does not exist at resolved path: $resolvedPath (original: $directoryPath). This indicates the directory was moved/renamed after bookmark creation.');
         throw DirectoryNotFoundError('Directory does not exist: $resolvedPath');
       }
       LoggingService.instance.info('Directory exists at resolved path, starting scan');

       final mediaItems = <MediaModel>[];

       // First, scan for subdirectories
       LoggingService.instance.debug('Scanning for subdirectories');
       final subdirScanStart = DateTime.now();
       await for (final entity in directory.list(
         recursive: false,
         followLinks: false,
       )) {
         if (entity is Directory) {
           final dirName = path.basename(entity.path);
           if (!dirName.startsWith('.') && !_excludedFiles.contains(dirName)) {
             final dirStat = await entity.stat();
             final dirId = _generateId(entity.path);

             mediaItems.add(
               MediaModel(
                 id: dirId,
                 path: entity.path,
                 name: dirName,
                 type: MediaType.directory,
                 size: 0, // Directories don't have a size in the same way
                 lastModified: dirStat.modified,
                 directoryId: directoryId,
                 tagIds: const [],
                 bookmarkData: null, // Subdirectories inherit access from parent directory
               ),
             );
           }
         }
       }
       final subdirScanDuration = DateTime.now().difference(subdirScanStart);
       LoggingService.instance.info('Found ${mediaItems.where((m) => m.type == MediaType.directory).length} subdirectories, subdir scan took ${subdirScanDuration.inMilliseconds}ms');

       // Then scan for media files
       LoggingService.instance.debug('Starting recursive scan for media files');
       final fileScanStart = DateTime.now();
       await _scanDirectoryRecursive(directory, directoryId, mediaItems);
       final fileScanDuration = DateTime.now().difference(fileScanStart);
       final fileCount = mediaItems.where((m) => m.type != MediaType.directory).length;
       LoggingService.instance.info('Scan completed, found $fileCount media files, file scan took ${fileScanDuration.inMilliseconds}ms');

       final totalScanDuration = DateTime.now().difference(scanStartTime);
       LoggingService.instance.info('Total scan duration: ${totalScanDuration.inMilliseconds}ms for ${mediaItems.length} items');

       return mediaItems;
    } catch (e) {
      // Log detailed error information for debugging
      final errorMessage = e.toString();
      _permissionSvc.logPermissionEvent(
        'scan_failed',
        path: resolvedPath,
        error: errorMessage,
        details: 'started_access=$startedAccess',
      );

      LoggingService.instance.error('Failed to scan directory $resolvedPath: $e');
      if (errorMessage.contains('Operation not permitted') || errorMessage.contains('errno = 1')) {
        _permissionSvc.logPermissionEvent(
          'permission_denied_detected',
          path: resolvedPath,
          error: errorMessage,
        );
        LoggingService.instance.warning('Permission denied - security-scoped bookmark may have expired for directory: $resolvedPath');
        throw DirectoryAccessDeniedError('Permission denied scanning directory: $resolvedPath');
      }
      throw DirectoryScanError('Failed to scan directory: $e');
    } finally {
      // Stop accessing bookmark if we started it
      if (startedAccess && effectiveBookmarkData != null) {
        try {
          await _bookmarkService.stopAccessingBookmark(effectiveBookmarkData);
          LoggingService.instance.debug('Stopped accessing bookmark for directory: $directoryPath');
        } catch (e) {
          LoggingService.instance.warning('Failed to stop accessing bookmark for directory $directoryPath: $e');
          // Don't throw - cleanup failure shouldn't break the operation
        }
      }
    }
  }

  /// Scans a directory for subdirectories (for navigation).
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
          // Skip hidden directories
          final dirName = path.basename(entity.path);
          if (!dirName.startsWith('.')) {
            subdirectories.add(entity.path);
          }
        }
      }
      return subdirectories;
    } catch (e) {
      return [];
    }
  }

  /// Recursively scans a directory for media files.
   Future<void> _scanDirectoryRecursive(
     Directory directory,
     String directoryId,
     List<MediaModel> mediaFiles,
   ) async {
     LoggingService.instance.debug('Scanning directory recursively: ${directory.path}');
     final scanStart = DateTime.now();

     try {
       // First, collect all file entities
       final fileEntities = <File>[];
       await for (final entity in directory.list(
         recursive: false,
         followLinks: false,
       )) {
         if (entity is File) {
           fileEntities.add(entity);
         } else if (entity is Directory) {
           // For nested directories, we could add them as special media items
           // but for now, we'll focus on files only
           continue;
         }
       }

       LoggingService.instance.debug('Found ${fileEntities.length} files to process');

       // Process files in parallel batches to improve performance
       const batchSize = 10; // Process 10 files concurrently
       final batches = <List<File>>[];
       for (var i = 0; i < fileEntities.length; i += batchSize) {
         final end = (i + batchSize < fileEntities.length) ? i + batchSize : fileEntities.length;
         batches.add(fileEntities.sublist(i, end));
       }

       LoggingService.instance.debug('Processing ${batches.length} batches of files');

       for (final batch in batches) {
         final batchFutures = batch.map((file) => _processFile(file, directoryId));
         final batchResults = await Future.wait(batchFutures);

         for (final media in batchResults) {
           if (media != null) {
             mediaFiles.add(media);
           }
         }
       }

       final scanDuration = DateTime.now().difference(scanStart);
       final processedFiles = fileEntities.length;
       final mediaFilesFound = mediaFiles.length - mediaFiles.where((m) => m.type == MediaType.directory).length;

       LoggingService.instance.debug('Completed scanning directory: ${directory.path}, processed $processedFiles files, found $mediaFilesFound media files, took ${scanDuration.inMilliseconds}ms');
     } catch (e) {
       // Log permission errors for debugging
       LoggingService.instance.error('Failed to scan subdirectory ${directory.path}: $e');
       if (e.toString().contains('Operation not permitted') || e.toString().contains('errno = 1')) {
         LoggingService.instance.warning('Permission denied in subdirectory - security-scoped bookmark may have expired for: ${directory.path}');
       }
       // Skip directories we can't access
       return;
     }
   }

  /// Processes a single file to determine if it's media and create a MediaModel.
   Future<MediaModel?> _processFile(File file, String directoryId) async {
     final fileName = path.basename(file.path);
     final extension = path
         .extension(file.path)
         .toLowerCase()
         .replaceFirst('.', '');

     // Skip excluded files
     if (_isExcludedFile(fileName)) {
       return null;
     }

     // Determine media type
     final mediaType = _getMediaType(extension);
     if (mediaType == null) {
       return null;
     }

     try {
       // Get file stats - this is the potential bottleneck
       final statStart = DateTime.now();
       final stat = await file.stat();
       final statDuration = DateTime.now().difference(statStart);
       final size = stat.size;
       final lastModified = stat.modified;

       // Log slow file.stat() calls (over 10ms)
       if (statDuration.inMilliseconds > 10) {
         LoggingService.instance.warning('Slow file.stat() for ${file.path}: ${statDuration.inMilliseconds}ms');
       }

       // Generate ID from file system metadata for consistency across different access paths
       final id = _generateIdFromMetadata(stat, file.path);

       return MediaModel(
         id: id,
         path: file.path,
         name: fileName,
         type: mediaType,
         size: size,
         lastModified: lastModified,
         directoryId: directoryId,
         tagIds: const [],
       );
     } catch (e) {
       // Skip files we can't process
       LoggingService.instance.debug('Failed to process file ${file.path}: $e');
       return null;
     }
   }

  /// Determines the media type from file extension.
  MediaType? _getMediaType(String extension) {
    if (_imageExtensions.contains(extension)) {
      return MediaType.image;
    } else if (_videoExtensions.contains(extension)) {
      return MediaType.video;
    } else if (_textExtensions.contains(extension)) {
      return MediaType.text;
    }
    return null;
  }

  /// Checks if a file should be excluded.
  bool _isExcludedFile(String fileName) {
    return _excludedFiles.any((excluded) => fileName.startsWith(excluded));
  }

  /// Generates a unique ID from file metadata for consistency across different access paths.
  String _generateIdFromMetadata(FileStat stat, String filePath) {
    // Use file size, modification time, and filename for consistent identification
    // This combination should be unique for each file and consistent across different access paths
    final fileName = path.basename(filePath);
    final idString = '${stat.size}_${stat.modified.millisecondsSinceEpoch}_$fileName';
    final bytes = utf8.encode(idString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a unique ID from file path using SHA-256.
  /// Normalizes the path to ensure consistent IDs regardless of how the path was resolved.
  String _generateId(String filePath) {
    // Normalize the path by resolving symlinks and getting the canonical path
    final normalizedPath = _normalizePath(filePath);
    final bytes = utf8.encode(normalizedPath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Normalizes a file path by resolving symlinks and getting the canonical path.
  /// This ensures consistent IDs regardless of bookmark resolution or symlink differences.
  String _normalizePath(String filePath) {
    try {
      final file = File(filePath);
      // Get the canonical path (resolves symlinks and normalizes the path)
      final canonicalPath = file.absolute.path;
      // On macOS, we need to handle the case where bookmark resolution gives us
      // a different path structure. For consistency, we'll use the resolved path
      // but normalize it to remove any redundant components.
      return path.normalize(canonicalPath);
    } catch (e) {
      // If normalization fails, fall back to the original path normalization
      return path.normalize(filePath);
    }
  }

  /// Gets media file by ID (requires rescanning the directory).
  Future<MediaModel?> getMediaById(
    String mediaId,
    String directoryPath,
    String directoryId, {
    String? bookmarkData,
  }) async {
    // Note: scanMediaForDirectory already handles bookmark access lifecycle
    final allMedia = await scanMediaForDirectory(directoryPath, directoryId, bookmarkData: bookmarkData);
    return allMedia.where((media) => media.id == mediaId).firstOrNull;
  }

  /// Filters media by tag IDs (requires rescanning and filtering).
  Future<List<MediaModel>> filterMediaByTags(
    String directoryPath,
    String directoryId,
    List<String> tagIds, {
    String? bookmarkData,
    IsarMediaDataSource? mediaPersistence,
  }) async {
    // Note: scanMediaForDirectory already handles bookmark access lifecycle
    final allMedia = await scanMediaForDirectory(directoryPath, directoryId, bookmarkData: bookmarkData);

    // If we have a shared preferences data source, merge tagIds from persisted data
    List<MediaModel> mediaWithTags = allMedia;
    if (mediaPersistence != null) {
      final existingMedia = await mediaPersistence.getMedia();
      final existingMediaMap = {for (final m in existingMedia) m.id: m};

      // Convert entities back to models for persistence, merging tagIds from persisted data
      mediaWithTags = allMedia.map((entity) {
        final existing = existingMediaMap[entity.id];
        return MediaModel(
          id: entity.id,
          path: entity.path,
          name: entity.name,
          type: entity.type,
          size: entity.size,
          lastModified: entity.lastModified,
          tagIds: existing?.tagIds ?? entity.tagIds, // Merge tagIds from persisted data
          directoryId: entity.directoryId,
          bookmarkData: entity.bookmarkData,
        );
      }).toList();
    }

    if (tagIds.isEmpty) return mediaWithTags;
    return mediaWithTags
        .where((media) => media.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();
  }

}
