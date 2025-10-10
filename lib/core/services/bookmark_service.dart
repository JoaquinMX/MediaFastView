import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
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

  // Singleton instance
  static final BookmarkService instance = BookmarkService._();

  BookmarkService._();

  /// Tracks bookmarks that should remain accessible for the lifetime of the app.
  ///
  /// The key is the base64 bookmark data and the value is the resolved path returned
  /// when starting access. This lets callers refresh directory paths when the
  /// bookmark resolves to a different location (e.g., when a drive is remounted).
  final Map<String, String> _activePersistentBookmarks = <String, String>{};

  /// Creates a security-scoped bookmark from a directory URL
  /// Returns base64 encoded bookmark data on success
  Future<String> createBookmark(String directoryPath) async {
    try {
      if (!Platform.isMacOS) {
        throw UnsupportedError(
          'Bookmark operations are only supported on macOS',
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
      if (!Platform.isMacOS) {
        throw UnsupportedError(
          'Bookmark operations are only supported on macOS',
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
      if (!Platform.isMacOS) {
        return; // No-op on non-macOS platforms
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

  /// Ensures that the provided bookmark keeps its security-scoped access for the
  /// lifetime of the current application session.
  ///
  /// Returns the resolved path when the bookmark access is successfully started.
  Future<String?> ensurePersistentAccess(String? bookmarkData) async {
    final bookmarkValue = bookmarkData;
    if (bookmarkValue == null || bookmarkValue.isEmpty) {
      return null;
    }

    if (!Platform.isMacOS) {
      // Security scoped bookmarks are only relevant on macOS.
      return null;
    }

    final existingPath = _activePersistentBookmarks[bookmarkValue];
    if (existingPath != null) {
      return existingPath;
    }

    try {
      final resolvedPath = await startAccessingBookmark(bookmarkValue);
      _activePersistentBookmarks[bookmarkValue] = resolvedPath;
      return resolvedPath;
    } catch (e) {
      _logError('Failed to keep bookmark access active', e);
      return null;
    }
  }

  /// Releases a bookmark that was previously kept active via [ensurePersistentAccess].
  Future<void> releasePersistentAccess(String? bookmarkData) async {
    final bookmarkValue = bookmarkData;
    if (bookmarkValue == null || bookmarkValue.isEmpty) {
      return;
    }

    if (!Platform.isMacOS) {
      return;
    }

    final hasActiveAccess = _activePersistentBookmarks.remove(bookmarkValue) != null;
    if (!hasActiveAccess) {
      return;
    }

    try {
      await stopAccessingBookmark(bookmarkValue);
    } catch (e) {
      _logError('Failed to release persistent bookmark access', e);
    }
  }

  /// Releases all persistent bookmark sessions. Useful when clearing cached directories.
  Future<void> releaseAllPersistentAccesses() async {
    if (!Platform.isMacOS) {
      return;
    }

    final bookmarks = List<String>.from(_activePersistentBookmarks.keys);
    _activePersistentBookmarks.clear();

    for (final bookmark in bookmarks) {
      try {
        await stopAccessingBookmark(bookmark);
      } catch (e) {
        _logError('Failed to release bookmark during bulk cleanup', e);
      }
    }
  }

  /// Checks if a security-scoped bookmark is still valid
  /// Takes base64 encoded bookmark data and returns true if valid
  Future<bool> isBookmarkValid(String bookmarkData) async {
    try {
      if (!Platform.isMacOS) {
        throw UnsupportedError(
          'Bookmark operations are only supported on macOS',
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
      if (!Platform.isMacOS) {
        throw UnsupportedError(
          'Bookmark operations are only supported on macOS',
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

  void _logError(String message, dynamic error) {
    // Use the logging service
    LoggingService.instance.error('[BookmarkService] $message: $error');
  }
}
