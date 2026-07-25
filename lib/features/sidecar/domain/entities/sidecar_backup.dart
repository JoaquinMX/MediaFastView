import 'package:path/path.dart' as p;

import 'sidecar_manifest.dart';

/// Schema identifier for portable Media Fast View metadata backups.
const String kSidecarBackupSchema = 'media-fast-view/backup';

/// Current portable backup format version.
const int kSidecarBackupVersion = 1;

/// One saved library root and its embedded per-folder sidecar manifests.
class SidecarBackupRoot {
  const SidecarBackupRoot({
    required this.originalPath,
    required this.name,
    required this.manifestsByRelativeFolder,
  });

  /// Absolute library-root path at the time the backup was created.
  final String originalPath;

  /// Display name captured for root-mapping prompts.
  final String name;

  /// Root-relative folder path to the manifest that describes that folder.
  ///
  /// The root itself uses `.`. Paths always use forward slashes so the archive
  /// does not depend on the host platform's separator.
  final Map<String, SidecarManifest> manifestsByRelativeFolder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'originalPath': originalPath,
    'name': name,
    'manifests': <String, dynamic>{
      for (final entry in manifestsByRelativeFolder.entries)
        entry.key: entry.value.toJson(),
    },
  };

  static SidecarBackupRoot? fromJson(Map<String, dynamic> json) {
    final originalPath = json['originalPath'];
    final manifestsRaw = json['manifests'];
    if (originalPath is! String ||
        originalPath.trim().isEmpty ||
        manifestsRaw is! Map) {
      return null;
    }

    final manifests = <String, SidecarManifest>{};
    for (final entry in manifestsRaw.entries) {
      final relativeFolder = entry.key;
      final manifestJson = entry.value;
      if (relativeFolder is! String ||
          !_isSafeRelativeFolder(relativeFolder) ||
          manifestJson is! Map) {
        return null;
      }
      final manifest = SidecarManifest.fromJson(
        Map<String, dynamic>.from(manifestJson),
      );
      if (manifest == null ||
          manifest.files.keys.any((fileName) => !_isSafeFileName(fileName))) {
        return null;
      }
      manifests[relativeFolder] = manifest;
    }

    final rawName = json['name'];
    return SidecarBackupRoot(
      originalPath: originalPath,
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : p.basename(originalPath),
      manifestsByRelativeFolder: manifests,
    );
  }

  /// Whether [relativeFolder] stays beneath its mapped library root.
  static bool isSafeRelativeFolder(String relativeFolder) =>
      _isSafeRelativeFolder(relativeFolder);

  /// Whether [fileName] is a base name rather than a path.
  static bool isSafeFileName(String fileName) => _isSafeFileName(fileName);
}

/// A portable single-file backup of the active profile's sidecar metadata.
class SidecarBackup {
  const SidecarBackup({
    required this.generatedAt,
    this.roots = const <SidecarBackupRoot>[],
  });

  final DateTime generatedAt;
  final List<SidecarBackupRoot> roots;

  bool get isEmpty =>
      roots.every((root) => root.manifestsByRelativeFolder.isEmpty);

  int get manifestCount => roots.fold<int>(
    0,
    (count, root) => count + root.manifestsByRelativeFolder.length,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': kSidecarBackupSchema,
    'version': kSidecarBackupVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'roots': roots.map((root) => root.toJson()).toList(growable: false),
  };

  static SidecarBackup? fromJson(Map<String, dynamic> json) {
    if (json['schema'] != kSidecarBackupSchema ||
        json['version'] != kSidecarBackupVersion) {
      return null;
    }

    final rootsRaw = json['roots'];
    if (rootsRaw is! List) {
      return null;
    }

    final roots = <SidecarBackupRoot>[];
    final normalizedPaths = <String>{};
    for (final rootJson in rootsRaw) {
      if (rootJson is! Map) {
        return null;
      }
      final root = SidecarBackupRoot.fromJson(
        Map<String, dynamic>.from(rootJson),
      );
      if (root == null) {
        return null;
      }
      final normalizedPath = p.normalize(root.originalPath);
      if (!normalizedPaths.add(normalizedPath)) {
        return null;
      }
      roots.add(root);
    }

    return SidecarBackup(
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      roots: roots,
    );
  }
}

bool _isSafeRelativeFolder(String relativeFolder) {
  if (relativeFolder == '.') {
    return true;
  }
  if (relativeFolder.isEmpty || p.posix.isAbsolute(relativeFolder)) {
    return false;
  }
  final normalized = p.posix.normalize(relativeFolder);
  return normalized == relativeFolder &&
      normalized != '..' &&
      !normalized.startsWith('../');
}

bool _isSafeFileName(String fileName) {
  return fileName.isNotEmpty &&
      fileName != '.' &&
      fileName != '..' &&
      !p.posix.isAbsolute(fileName) &&
      p.posix.basename(fileName) == fileName;
}
