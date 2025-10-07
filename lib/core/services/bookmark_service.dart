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
