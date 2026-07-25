import 'sidecar_backup.dart';

/// Summary of an export run, surfaced to the user as a one-line result.
class SidecarExportResult {
  const SidecarExportResult({
    this.rootsSaved = 0,
    this.manifestsSaved = 0,
    this.filesCovered = 0,
    this.favoritesCovered = 0,
    this.failures = const <String>[],
  });

  final int rootsSaved;

  /// Number of embedded folder manifests in the portable backup.
  final int manifestsSaved;

  /// Number of per-file entries written across all manifests.
  final int filesCovered;

  /// Number of favorite entries written (media + folder).
  final int favoritesCovered;

  /// Cached folders that could not be assigned to a tracked library root.
  final List<String> failures;

  bool get hasFailures => failures.isNotEmpty;

  /// The one-line summary shown after a run.
  String describe() {
    if (manifestsSaved == 0 && !hasFailures) {
      return 'No tagged or favorited items to save.';
    }
    if (manifestsSaved == 0) {
      return 'No backup was saved. ${failures.length} '
          'folder${failures.length == 1 ? '' : 's'} could not be assigned to '
          'a tracked library root.';
    }
    final buffer = StringBuffer(
      'Saved one backup with $manifestsSaved '
      'folder record${manifestsSaved == 1 ? '' : 's'} covering $filesCovered '
      'file${filesCovered == 1 ? '' : 's'}',
    );
    if (favoritesCovered > 0) {
      buffer.write(
        ' and $favoritesCovered '
        'favorite${favoritesCovered == 1 ? '' : 's'}',
      );
    }
    buffer.write('.');
    if (hasFailures) {
      buffer.write(
        ' ${failures.length} '
        'folder${failures.length == 1 ? '' : 's'} could not be assigned to '
        'a tracked library root.',
      );
    }
    return buffer.toString();
  }
}

/// Backup payload and counts produced before the user chooses a save location.
class SidecarExportPreparation {
  const SidecarExportPreparation({required this.backup, required this.result});

  final SidecarBackup backup;
  final SidecarExportResult result;
}

/// Summary of an import run, surfaced to the user as a one-line result.
class SidecarImportResult {
  const SidecarImportResult({
    this.manifestsRead = 0,
    this.filesLinked = 0,
    this.tagsCreated = 0,
    this.favoritesApplied = 0,
    this.filesNotFound = 0,
    this.rootsSkipped = 0,
    this.failures = const <String>[],
  });

  /// Number of manifests successfully read and parsed.
  final int manifestsRead;

  /// Number of files whose tags/favorite were re-linked onto a media id.
  final int filesLinked;

  /// Number of tags created in the active profile because no tag of that name
  /// existed yet.
  final int tagsCreated;

  /// Number of favorite entries applied (media + folder).
  final int favoritesApplied;

  /// Number of file entries whose file was not found on disk (renamed, moved
  /// away, or its metadata changed) and were skipped.
  final int filesNotFound;

  /// Saved roots the user explicitly left unmapped.
  final int rootsSkipped;

  /// Folder paths that could not be read or applied.
  final List<String> failures;

  bool get hasFailures => failures.isNotEmpty;

  bool get foundNothing =>
      manifestsRead == 0 && rootsSkipped == 0 && !hasFailures;

  /// The one-line summary shown after a run.
  String describe() {
    if (foundNothing) {
      return 'The backup contains no tags or favorites to load.';
    }
    final buffer = StringBuffer(
      'Imported tags for $filesLinked '
      'file${filesLinked == 1 ? '' : 's'}',
    );
    if (tagsCreated > 0) {
      buffer.write(
        ' ($tagsCreated new tag${tagsCreated == 1 ? '' : 's'} '
        'created)',
      );
    }
    if (favoritesApplied > 0) {
      buffer.write(
        ', $favoritesApplied '
        'favorite${favoritesApplied == 1 ? '' : 's'} restored',
      );
    }
    buffer.write('.');
    if (filesNotFound > 0) {
      buffer.write(
        ' $filesNotFound '
        'file${filesNotFound == 1 ? '' : 's'} in manifests were not found '
        'on disk and were skipped.',
      );
    }
    if (rootsSkipped > 0) {
      buffer.write(
        ' $rootsSkipped saved library '
        'root${rootsSkipped == 1 ? '' : 's'} skipped.',
      );
    }
    if (hasFailures) {
      buffer.write(
        ' ${failures.length} '
        'folder${failures.length == 1 ? '' : 's'} could not be read.',
      );
    }
    return buffer.toString();
  }
}
