import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wrapper for the bookmarks MethodChannel used by native pickers.
final class BookmarksChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.joaquinmx.media_fast_view/bookmarks',
  );

  BookmarksChannel._();

  /// Returns file:// URIs selected by the iOS document picker.
  ///
  /// This is session-only access on iOS; if persistent access is needed, copy
  /// files into the app's container during the session.
  ///
  /// The method is iOS-specific; guard with [Platform.isIOS] if needed.
  static Future<List<Uri>> pickDirectoryOrFiles() async {
    if (!Platform.isIOS) {
      return const <Uri>[];
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'pickDirectoryOrFiles',
      );

      if (result == null) {
        return const <Uri>[];
      }

      return result
          .whereType<String>()
          .map(Uri.parse)
          .where((uri) => uri.scheme == 'file')
          .toList();
    } on FlutterError catch (error) {
      debugPrint('pickDirectoryOrFiles failed: ${error.message}');
      return const <Uri>[];
    } on PlatformException catch (error) {
      debugPrint('pickDirectoryOrFiles platform error: ${error.message}');
      return const <Uri>[];
    } catch (error) {
      debugPrint('pickDirectoryOrFiles unexpected error: $error');
      return const <Uri>[];
    }
  }
}

/// Example usage:
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     final uris = await BookmarksChannel.pickDirectoryOrFiles();
///     if (uris.isEmpty) {
///       debugPrint('No selection or picker dismissed.');
///       return;
///     }
///     for (final uri in uris) {
///       debugPrint('Picked: $uri');
///     }
///   },
///   child: const Text('Pick Directory or Files'),
/// )
/// ```
