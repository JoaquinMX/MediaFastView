import 'package:path/path.dart' as p;

import '../../features/media_library/domain/entities/directory_entity.dart';

/// Finds the security-scoped bookmark that grants sandboxed access to [path].
///
/// Only tracked library roots carry a bookmark — sub-directories never get a
/// `DirectoryEntity`, and the rows scanned for them are stored with a null
/// bookmark because they "inherit access from parent directory". So access to an
/// arbitrary path rides on the **deepest tracked root containing it**, whose
/// scope covers everything beneath.
///
/// Deepest rather than first: when a user has added both `/Photos` and
/// `/Photos/2024`, the more specific bookmark is the one that reliably covers
/// the path. Returns `null` when no tracked root covers [path].
String? resolveBookmarkForPath(
  String path,
  List<DirectoryEntity> directories,
) {
  DirectoryEntity? enclosing;

  for (final directory in directories) {
    if (directory.bookmarkData == null) {
      continue;
    }
    final coversPath =
        path == directory.path || p.isWithin(directory.path, path);
    if (!coversPath) {
      continue;
    }
    if (enclosing == null || directory.path.length > enclosing.path.length) {
      enclosing = directory;
    }
  }

  return enclosing?.bookmarkData;
}

/// Decides which directory to actually scan, given the directory we were asked
/// for ([directoryPath]) and the path a bookmark resolved to ([scopePath]).
///
/// A bookmark grants a **scope**; it does not say what to read. Those are only
/// the same thing when the bookmark belongs to the directory being scanned —
/// true for a tracked library root, false for a sub-directory, which has no
/// bookmark of its own and must borrow its enclosing root's. Scanning the
/// resolved path in that case silently reads the *root*, which is how "go to
/// directory" came to show the root's media under the sub-directory's name.
///
/// [scopePath] therefore wins only when it cannot be an enclosing root — when
/// [directoryPath] is not inside it. That is precisely the case the behaviour
/// was written for: a bookmarked directory that has since been moved or renamed,
/// where the stored path is stale and the bookmark knows better.
String resolveScanTarget(String directoryPath, String scopePath) {
  if (p.equals(scopePath, directoryPath) ||
      p.isWithin(scopePath, directoryPath)) {
    return directoryPath;
  }
  return scopePath;
}
