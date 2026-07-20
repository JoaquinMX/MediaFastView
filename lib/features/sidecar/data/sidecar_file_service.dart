import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/bookmark_service.dart';
import '../../../core/services/logging_service.dart';
import '../domain/entities/sidecar_file_stat.dart';
import '../domain/entities/sidecar_manifest.dart';

/// Reads and writes `.mediafastview.json` manifests inside sandboxed library
/// folders.
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
  Future<T> withAccess<T>(
    String? bookmarkData,
    Future<T> Function() body,
  );

  /// Writes [contents] to `<folderPath>/.mediafastview.json`, overwriting any
  /// existing manifest. Requires scope held via [withAccess].
  Future<void> writeManifest(String folderPath, String contents);

  /// Reads `<folderPath>/.mediafastview.json`, or returns null when absent.
  /// Requires scope held via [withAccess].
  Future<String?> readManifest(String folderPath);

  /// Returns the folder paths under [rootPath] (inclusive) that contain a
  /// manifest. Requires scope held via [withAccess].
  Future<List<String>> findManifestFolders(String rootPath);

  /// Stats [filePath], or returns null when the file does not exist. Requires
  /// scope held via [withAccess].
  Future<SidecarFileStat?> statFile(String filePath);

  /// Whether [folderPath] still exists on disk. Requires scope held via
  /// [withAccess]. Used to tell a stale cache entry (folder deleted or moved
  /// outside the app) apart from a genuine write failure.
  Future<bool> folderExists(String folderPath);
}

/// Production [SidecarFileService] backed by [BookmarkService] scoped access and
/// `dart:io`.
class BookmarkSidecarFileService implements SidecarFileService {
  const BookmarkSidecarFileService({BookmarkService? bookmarkService})
      : _bookmarkService = bookmarkService;

  final BookmarkService? _bookmarkService;

  BookmarkService get _bookmarks => _bookmarkService ?? BookmarkService.instance;

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
  Future<void> writeManifest(String folderPath, String contents) async {
    final file = File(p.join(folderPath, kSidecarManifestFileName));
    await file.writeAsString(contents, flush: true);
  }

  @override
  Future<String?> readManifest(String folderPath) async {
    final file = File(p.join(folderPath, kSidecarManifestFileName));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<List<String>> findManifestFolders(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      return const <String>[];
    }

    // A set, not a list: a recursive walk yields the root's own manifest as a
    // direct child, and nested tracked roots can overlap, so a folder must never
    // be collected — and later processed — twice.
    final folders = <String>{};

    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            p.basename(entity.path) == kSidecarManifestFileName) {
          folders.add(p.dirname(entity.path));
        }
      }
    } on FileSystemException catch (error) {
      // A permission hiccup partway through a large tree should still yield the
      // folders found so far rather than nothing.
      LoggingService.instance.warning(
        '[Sidecar] Stopped walking "$rootPath" early: ${error.message}',
      );
    }

    return folders.toList();
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

  @override
  Future<bool> folderExists(String folderPath) =>
      Directory(folderPath).exists();
}
