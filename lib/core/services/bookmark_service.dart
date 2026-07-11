import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../error/app_error.dart';
import 'file_transfer_result.dart';
import 'logging_service.dart';

/// Service for handling macOS security-scoped bookmark operations
class BookmarkService {
  static const MethodChannel _channel = MethodChannel(
    'com.joaquinmx.media_fast_view/bookmarks',
  );
  static const String _createBookmark = 'createBookmark';
  static const String _selectDirectoryAndCreateBookmark =
      'selectDirectoryAndCreateBookmark';
  static const String _resolveBookmark = 'resolveBookmark';
  static const String _isBookmarkValid = 'isBookmarkValid';
  static const String _startAccessingBookmark = 'startAccessingBookmark';
  static const String _stopAccessingBookmark = 'stopAccessingBookmark';
  static const String _moveToTrash = 'moveToTrash';
  static const String _moveItem = 'moveItem';
  static const String _copyItem = 'copyItem';

  // Singleton instance
  static final BookmarkService instance = BookmarkService._();

  BookmarkService._();

  bool get _supportsBookmarks => Platform.isMacOS || Platform.isIOS;

  /// Creates a security-scoped bookmark from a directory URL
  /// Returns base64 encoded bookmark data on success
  Future<String> createBookmark(String directoryPath) async {
    try {
      if (!_supportsBookmarks) {
        throw UnsupportedError(
          'Bookmark operations are only supported on Apple platforms',
        );
      }

      final result = await _channel.invokeMethod<String>(_createBookmark, {
        'directoryPath': directoryPath,
      });

      if (result == null) {
        throw Exception('Failed to create bookmark: null result');
      }

      return result;
    } on PlatformException catch (e) {
      _logError('Failed to create bookmark for path: $directoryPath', e);
      throw Exception('Failed to create bookmark: ${e.message}');
    } catch (e) {
      _logError(
        'Unexpected error creating bookmark for path: $directoryPath',
        e,
      );
      throw Exception('Unexpected error creating bookmark: $e');
    }
  }

  /// Shows a directory selection panel and creates a security-scoped bookmark
  /// Returns a map containing 'directoryPath' and 'bookmarkData' on success
  Future<Map<String, dynamic>> selectDirectoryAndCreateBookmark({
    String? initialDirectoryPath,
  }) async {
    try {
      if (!Platform.isMacOS) {
        throw UnsupportedError(
          'Bookmark operations are only supported on macOS',
        );
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        _selectDirectoryAndCreateBookmark,
        {
          if (initialDirectoryPath != null)
            'initialDirectoryPath': initialDirectoryPath,
        },
      );

      if (result == null) {
        throw Exception(
          'Failed to select directory and create bookmark: null result',
        );
      }

      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      _logError('Failed to select directory and create bookmark', e);
      throw Exception(
        'Failed to select directory and create bookmark: ${e.message}',
      );
    } catch (e) {
      _logError(
        'Unexpected error selecting directory and creating bookmark',
        e,
      );
      throw Exception(
        'Unexpected error selecting directory and creating bookmark: $e',
      );
    }
  }

  /// Resolves a security-scoped bookmark to regain access
  /// Takes base64 encoded bookmark data and returns the resolved path
  /// Note: The caller is responsible for calling stopAccessingBookmark when done
  Future<String> resolveBookmark(String bookmarkData) async {
    try {
      if (!_supportsBookmarks) {
        throw UnsupportedError(
          'Bookmark operations are only supported on Apple platforms',
        );
      }

      final result = await _channel.invokeMethod<String>(_resolveBookmark, {
        'bookmarkData': bookmarkData,
      });

      if (result == null) {
        throw Exception('Failed to resolve bookmark: null result');
      }

      return result;
    } on PlatformException catch (e) {
      _logError('Failed to resolve bookmark', e);
      throw Exception('Failed to resolve bookmark: ${e.message}');
    } catch (e) {
      _logError('Unexpected error resolving bookmark', e);
      throw Exception('Unexpected error resolving bookmark: $e');
    }
  }

  /// Stops accessing a security-scoped bookmark
  /// Takes base64 encoded bookmark data
  Future<void> stopAccessingBookmark(String bookmarkData) async {
    try {
      if (!_supportsBookmarks) {
        return; // No-op on unsupported platforms
      }

      await _channel.invokeMethod<void>(_stopAccessingBookmark, {
        'bookmarkData': bookmarkData,
      });
    } on PlatformException catch (e) {
      _logError('Failed to stop accessing bookmark', e);
      // Don't throw - stopping access failure shouldn't break the app
    } catch (e) {
      _logError('Unexpected error stopping bookmark access', e);
      // Don't throw - stopping access failure shouldn't break the app
    }
  }

  /// Checks if a security-scoped bookmark is still valid
  /// Takes base64 encoded bookmark data and returns true if valid
  Future<bool> isBookmarkValid(String bookmarkData) async {
    try {
      if (!_supportsBookmarks) {
        throw UnsupportedError(
          'Bookmark operations are only supported on Apple platforms',
        );
      }

      final result = await _channel.invokeMethod<bool>(_isBookmarkValid, {
        'bookmarkData': bookmarkData,
      });

      return result ?? false;
    } on PlatformException catch (e) {
      _logError('Failed to check bookmark validity', e);
      return false;
    } catch (e) {
      _logError('Unexpected error checking bookmark validity', e);
      return false;
    }
  }

  /// Starts accessing a security-scoped bookmark
  /// Takes base64 encoded bookmark data and starts access to the resource
  /// Returns the resolved path
  Future<String> startAccessingBookmark(String bookmarkData) async {
    try {
      if (!_supportsBookmarks) {
        throw UnsupportedError(
          'Bookmark operations are only supported on Apple platforms',
        );
      }

      final result = await _channel.invokeMethod<String>(
        _startAccessingBookmark,
        {'bookmarkData': bookmarkData},
      );

      if (result == null) {
        throw Exception('Failed to start accessing bookmark: null result');
      }

      return result;
    } on PlatformException catch (e) {
      _logError('Failed to start accessing bookmark', e);
      throw Exception('Failed to start accessing bookmark: ${e.message}');
    } catch (e) {
      _logError('Unexpected error starting bookmark access', e);
      throw Exception('Unexpected error starting bookmark access: $e');
    }
  }

  /// Moves a file or directory to the system Trash (recoverable).
  ///
  /// macOS only. Runs the operation inside security-scoped access to the
  /// enclosing bookmarked directory when [bookmarkData] is provided. Returns
  /// the resulting Trash path when available.
  Future<String?> moveToTrash(String path, {String? bookmarkData}) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError(
        'Moving items to Trash is only supported on macOS',
      );
    }

    try {
      return await _channel.invokeMethod<String>(_moveToTrash, {
        'path': path,
        if (bookmarkData != null) 'bookmarkData': bookmarkData,
      });
    } on PlatformException catch (e) {
      _logError('Failed to move item to Trash: $path', e);
      throw Exception('Failed to move item to Trash: ${e.message}');
    } catch (e) {
      _logError('Unexpected error moving item to Trash: $path', e);
      throw Exception('Unexpected error moving item to Trash: $e');
    }
  }

  /// Moves an item to [destinationPath] (a full path including the file name).
  ///
  /// macOS only. The native call holds security-scoped access to both the source
  /// and the destination for the duration of the transfer, which is why both
  /// bookmarks are threaded through.
  Future<FileTransferResult> moveItem({
    required String sourcePath,
    required String destinationPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _transfer(
      method: _moveItem,
      label: 'move',
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }

  /// Copies an item to [destinationPath] (a full path including the file name).
  ///
  /// macOS only. The native call stamps a fresh modification time on the copy so
  /// it takes on an identity of its own rather than colliding with its source.
  Future<FileTransferResult> copyItem({
    required String sourcePath,
    required String destinationPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _transfer(
      method: _copyItem,
      label: 'copy',
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }

  Future<FileTransferResult> _transfer({
    required String method,
    required String label,
    required String sourcePath,
    required String destinationPath,
    required String? sourceBookmarkData,
    required String? destinationBookmarkData,
    required ConflictStrategy conflictStrategy,
  }) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError(
        'Moving and copying files is only supported on macOS',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(method, {
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
        if (sourceBookmarkData != null) 'sourceBookmarkData': sourceBookmarkData,
        if (destinationBookmarkData != null)
          'destinationBookmarkData': destinationBookmarkData,
        'conflictStrategy': conflictStrategy.name,
      });

      if (result == null) {
        throw FileMoveError('The $label returned no result');
      }
      return FileTransferResult.fromMap(result);
    } on PlatformException catch (e) {
      _logError('Failed to $label $sourcePath -> $destinationPath', e);
      throw _transferError(e, label: label);
    }
  }

  /// Maps a native failure onto a typed error.
  ///
  /// Unlike [moveToTrash], this deliberately preserves the native error code:
  /// the conflict prompt exists only because `DESTINATION_EXISTS` survives the
  /// trip back, carrying the name the item would take under "keep both".
  AppError _transferError(PlatformException e, {required String label}) {
    final message = e.message ?? 'The $label failed';

    switch (e.code) {
      case 'DESTINATION_EXISTS':
        final details = e.details as Map<Object?, Object?>?;
        return DestinationExistsError(
          message,
          destinationPath: details?['destinationPath'] as String? ?? '',
          suggestedPath: details?['suggestedPath'] as String? ?? '',
        );
      case 'DESTINATION_INSIDE_SOURCE':
        return DestinationInsideSourceError(message);
      case 'SAME_PATH':
        return SamePathError(message);
      case 'INSUFFICIENT_SPACE':
        return InsufficientSpaceError(message);
      case 'SOURCE_NOT_FOUND':
        return FileNotFoundError(message);
      case 'DESTINATION_PARENT_NOT_FOUND':
        return DirectoryNotFoundError(message);
      case 'BOOKMARK_ACCESS':
        return FileAccessDeniedError(message);
      default:
        return label == 'move' ? FileMoveError(message) : FileCopyError(message);
    }
  }

  void _logError(String message, dynamic error) {
    // Use the logging service
    LoggingService.instance.error('[BookmarkService] $message: $error');
  }
}
