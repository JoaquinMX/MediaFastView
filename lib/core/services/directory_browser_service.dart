import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bookmark_service.dart';
import 'directory_access_grant.dart';

/// Describes a directory displayed by the in-app directory browser.
final class BrowsableDirectory {
  const BrowsableDirectory({required this.path, required this.name});

  final String path;
  final String name;
}

/// Browses descendants of a directory the user granted through the system.
final class DirectoryBrowserService {
  DirectoryBrowserService({
    BookmarkService? bookmarkService,
    bool? supportsBookmarks,
  }) : _bookmarkService = bookmarkService ?? BookmarkService.instance,
       _supportsBookmarks =
           supportsBookmarks ?? (Platform.isIOS || Platform.isMacOS);

  final BookmarkService _bookmarkService;
  final bool _supportsBookmarks;

  /// Lists visible direct children of [directoryPath] within [rootGrant].
  Future<List<BrowsableDirectory>> listChildren(
    DirectoryAccessGrant rootGrant,
    String directoryPath,
  ) async {
    final normalizedRootPath = p.normalize(rootGrant.path);
    final normalizedDirectoryPath = p.normalize(directoryPath);
    _ensureDescendant(normalizedRootPath, normalizedDirectoryPath);

    return _withRootAccess(rootGrant, (resolvedRootPath) async {
      final resolvedDirectoryPath = _resolveDescendantPath(
        originalRootPath: normalizedRootPath,
        requestedPath: normalizedDirectoryPath,
        resolvedRootPath: resolvedRootPath,
      );
      final directory = Directory(resolvedDirectoryPath);
      if (!await directory.exists()) {
        throw FileSystemException(
          'Directory no longer exists',
          resolvedDirectoryPath,
        );
      }

      final children = <BrowsableDirectory>[];
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is! Directory) {
          continue;
        }
        final name = p.basename(entity.path);
        if (name.startsWith('.')) {
          continue;
        }
        children.add(BrowsableDirectory(path: entity.path, name: name));
      }
      children.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
      return children;
    });
  }

  /// Creates independent grants for selected descendants of [rootGrant].
  Future<List<DirectoryAccessGrant>> createGrants(
    DirectoryAccessGrant rootGrant,
    Iterable<String> selectedPaths,
  ) async {
    final normalizedRootPath = p.normalize(rootGrant.path);
    final uniquePaths = LinkedHashSet<String>.from(
      selectedPaths.map(p.normalize),
    );
    for (final selectedPath in uniquePaths) {
      _ensureDescendant(normalizedRootPath, selectedPath);
    }

    if (uniquePaths.isEmpty) {
      return const <DirectoryAccessGrant>[];
    }

    return _withRootAccess(rootGrant, (resolvedRootPath) async {
      final grants = <DirectoryAccessGrant>[];
      for (final selectedPath in uniquePaths) {
        final resolvedPath = _resolveDescendantPath(
          originalRootPath: normalizedRootPath,
          requestedPath: selectedPath,
          resolvedRootPath: resolvedRootPath,
        );
        final bookmarkData = switch ((
          p.equals(selectedPath, normalizedRootPath),
          _supportsBookmarks,
        )) {
          (true, _) => rootGrant.bookmarkData,
          (false, true) => await _bookmarkService.createBookmark(resolvedPath),
          (false, false) => null,
        };
        grants.add(
          DirectoryAccessGrant(path: resolvedPath, bookmarkData: bookmarkData),
        );
      }
      return grants;
    });
  }

  Future<T> _withRootAccess<T>(
    DirectoryAccessGrant rootGrant,
    Future<T> Function(String resolvedRootPath) operation,
  ) async {
    final bookmarkData = rootGrant.bookmarkData;
    if (!_supportsBookmarks || bookmarkData == null || bookmarkData.isEmpty) {
      return operation(p.normalize(rootGrant.path));
    }

    var startedAccess = false;
    try {
      final resolvedRootPath = await _bookmarkService.startAccessingBookmark(
        bookmarkData,
      );
      startedAccess = true;
      return await operation(p.normalize(resolvedRootPath));
    } finally {
      if (startedAccess) {
        await _bookmarkService.stopAccessingBookmark(bookmarkData);
      }
    }
  }

  void _ensureDescendant(String rootPath, String candidatePath) {
    if (p.equals(rootPath, candidatePath) ||
        p.isWithin(rootPath, candidatePath)) {
      return;
    }
    throw ArgumentError.value(
      candidatePath,
      'candidatePath',
      'Directory must be inside the granted parent',
    );
  }

  String _resolveDescendantPath({
    required String originalRootPath,
    required String requestedPath,
    required String resolvedRootPath,
  }) {
    if (p.equals(originalRootPath, requestedPath)) {
      return resolvedRootPath;
    }
    final relativePath = p.relative(requestedPath, from: originalRootPath);
    return p.normalize(p.join(resolvedRootPath, relativePath));
  }
}
