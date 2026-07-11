import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Media identity, centralized so that the filesystem scanner and anything that
/// has to predict what the scanner will produce (such as reconciling the cache
/// after a move or copy) cannot drift apart.
///
/// Two different schemes, and the difference matters:
///
/// * Files are identified by **metadata** — size, modification time and name.
///   The path is deliberately absent, so the same file keeps its identity when
///   reached through a different access path. It also means a plain move keeps
///   the id, while a rename or a cross-volume copy changes it.
/// * Directories are identified by **path**, so moving one always changes its
///   id.

/// Generates a media id for a file from the metadata a filesystem scan sees.
String generateMediaIdFromMetadata({
  required int size,
  required DateTime lastModified,
  required String fileName,
}) {
  final idString =
      '${size}_${lastModified.millisecondsSinceEpoch}_$fileName';
  return sha256.convert(utf8.encode(idString)).toString();
}

/// Generates a media id for a directory entry from its path.
String generateMediaIdFromPath(String filePath) {
  return sha256.convert(utf8.encode(normalizeMediaPath(filePath))).toString();
}

/// Normalizes a path so an id is stable regardless of how the path was
/// resolved (bookmark resolution and symlinks can yield different spellings of
/// the same location).
String normalizeMediaPath(String filePath) {
  try {
    return p.normalize(File(filePath).absolute.path);
  } catch (_) {
    return p.normalize(filePath);
  }
}
