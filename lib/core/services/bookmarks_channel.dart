import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'directory_access_grant.dart';

/// Wrapper for the bookmarks MethodChannel used by native pickers.
final class BookmarksChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.joaquinmx.media_fast_view/bookmarks',
  );

  BookmarksChannel._();

  /// Returns directories selected by the iOS document picker.
  ///
  /// The method is iOS-specific; guard with [Platform.isIOS] if needed.
  static Future<List<DirectoryAccessGrant>> pickDirectories({
    required bool allowsMultipleSelection,
  }) async {
    if (!Platform.isIOS) {
      return const <DirectoryAccessGrant>[];
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'pickDirectories',
        <String, dynamic>{'allowsMultipleSelection': allowsMultipleSelection},
      );

      if (result == null) {
        return const <DirectoryAccessGrant>[];
      }

      return decodeDirectoryPayloads(result);
    } on FlutterError catch (error) {
      debugPrint('pickDirectories failed: ${error.message}');
      rethrow;
    } on PlatformException catch (error) {
      debugPrint('pickDirectories platform error: ${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('pickDirectories unexpected error: $error');
      rethrow;
    }
  }

  @visibleForTesting
  static List<DirectoryAccessGrant> decodeDirectoryPayloads(
    List<dynamic> payloads,
  ) {
    return payloads
        .whereType<Map<dynamic, dynamic>>()
        .map((item) {
          final url = item['url'];
          final bookmarkData = item['bookmarkData'];
          if (url is! String || bookmarkData is! String) {
            return null;
          }
          final uri = Uri.tryParse(url);
          if (uri == null || uri.scheme != 'file') {
            return null;
          }
          return DirectoryAccessGrant(
            path: uri.toFilePath(),
            bookmarkData: bookmarkData,
          );
        })
        .whereType<DirectoryAccessGrant>()
        .toList(growable: false);
  }
}
