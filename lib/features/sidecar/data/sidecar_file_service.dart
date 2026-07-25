import 'dart:io';

import '../../../core/services/bookmark_service.dart';
import '../../../core/services/logging_service.dart';
import '../domain/entities/sidecar_file_stat.dart';

/// Reads live media metadata inside sandboxed library folders.
///
/// Every filesystem call must happen while the enclosing tracked root's
/// security-scoped bookmark is being accessed. Callers wrap a batch of reads or
/// writes in [withAccess]; the individual operations assume the scope is already
/// held.
abstract interface class SidecarFileService {
  /// Runs [body] while holding security-scoped access granted by [bookmarkData].
  ///
  /// A null [bookmarkData] runs [body] with no scope (useful in tests and on the
  /// rare path with no bookmark). Access is always released, even if [body]
  /// throws.
  Future<T> withAccess<T>(String? bookmarkData, Future<T> Function() body);

  /// Stats [filePath], or returns null when the file does not exist. Requires
  /// scope held via [withAccess].
  Future<SidecarFileStat?> statFile(String filePath);
}

/// Production [SidecarFileService] backed by [BookmarkService] scoped access and
/// `dart:io`.
class BookmarkSidecarFileService implements SidecarFileService {
  const BookmarkSidecarFileService({BookmarkService? bookmarkService})
    : _bookmarkService = bookmarkService;

  final BookmarkService? _bookmarkService;

  BookmarkService get _bookmarks =>
      _bookmarkService ?? BookmarkService.instance;

  @override
  Future<T> withAccess<T>(
    String? bookmarkData,
    Future<T> Function() body,
  ) async {
    if (bookmarkData == null) {
      return body();
    }

    // Ignore a failure to start access rather than aborting the whole run: the
    // process may already hold access to this location (e.g. an ancestor root),
    // in which case the subsequent reads/writes still succeed. A genuine denial
    // surfaces later as the individual file operation failing, which the use
    // cases record per-folder.
    try {
      await _bookmarks.startAccessingBookmark(bookmarkData);
    } catch (error) {
      LoggingService.instance.warning(
        '[Sidecar] Could not start scoped access; continuing: $error',
      );
    }

    try {
      return await body();
    } finally {
      await _bookmarks.stopAccessingBookmark(bookmarkData);
    }
  }

  @override
  Future<SidecarFileStat?> statFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    final stat = await file.stat();
    return SidecarFileStat(
      size: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    );
  }
}
