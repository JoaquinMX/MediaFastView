/// Summary of an export run, surfaced to the user as a one-line result.
class SidecarExportResult {
  const SidecarExportResult({
    this.foldersWritten = 0,
    this.filesCovered = 0,
    this.favoritesCovered = 0,
    this.foldersSkippedMissing = 0,
    this.failures = const <String>[],
  });

  /// Number of `.mediafastview.json` files written (folders with no tags and no
  /// favorites are skipped and not counted).
  final int foldersWritten;

  /// Number of per-file entries written across all manifests.
  final int filesCovered;

  /// Number of favorite entries written (media + folder).
  final int favoritesCovered;

  /// Folders that had cached tags/favorites but no longer exist on disk (deleted
  /// or moved outside the app), so nothing could be written there. Benign — the
  /// cache is simply stale — but reported so the count is not mistaken for a
  /// genuine failure.
  final int foldersSkippedMissing;

  /// Human-readable reasons for folders that exist but could not be written
  /// (permission/IO). Never silently dropped.
  final List<String> failures;

  bool get hasFailures => failures.isNotEmpty;

  /// The one-line summary shown after a run.
  String describe() {
    if (foldersWritten == 0 &&
        foldersSkippedMissing == 0 &&
        !hasFailures) {
      return 'No tagged or favorited items to save.';
    }
    final buffer = StringBuffer(
      'Saved $foldersWritten '
      'manifest${foldersWritten == 1 ? '' : 's'} covering $filesCovered '
      'tagged file${filesCovered == 1 ? '' : 's'}',
    );
    if (favoritesCovered > 0) {
      buffer.write(' and $favoritesCovered '
          'favorite${favoritesCovered == 1 ? '' : 's'}');
    }
    buffer.write('.');
    if (foldersSkippedMissing > 0) {
      buffer.write(' $foldersSkippedMissing '
          'folder${foldersSkippedMissing == 1 ? '' : 's'} in the cache no '
          'longer exist on disk and were skipped.');
    }
    if (hasFailures) {
      buffer.write(' ${failures.length} '
          'folder${failures.length == 1 ? '' : 's'} could not be written.');
    }
    return buffer.toString();
  }
}

/// Summary of an import run, surfaced to the user as a one-line result.
class SidecarImportResult {
  const SidecarImportResult({
    this.manifestsRead = 0,
    this.filesLinked = 0,
    this.tagsCreated = 0,
    this.favoritesApplied = 0,
    this.filesNotFound = 0,
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

  /// Human-readable reasons for manifests that could not be read/applied.
  final List<String> failures;

  bool get hasFailures => failures.isNotEmpty;

  bool get foundNothing =>
      manifestsRead == 0 && !hasFailures;

  /// The one-line summary shown after a run.
  String describe() {
    if (foundNothing) {
      return 'No .mediafastview.json files found in your library folders.';
    }
    final buffer = StringBuffer(
      'Imported tags for $filesLinked '
      'file${filesLinked == 1 ? '' : 's'}',
    );
    if (tagsCreated > 0) {
      buffer.write(' ($tagsCreated new tag${tagsCreated == 1 ? '' : 's'} '
          'created)');
    }
    if (favoritesApplied > 0) {
      buffer.write(', $favoritesApplied '
          'favorite${favoritesApplied == 1 ? '' : 's'} restored');
    }
    buffer.write('.');
    if (filesNotFound > 0) {
      buffer.write(' $filesNotFound '
          'file${filesNotFound == 1 ? '' : 's'} in manifests were not found '
          'on disk and were skipped.');
    }
    if (hasFailures) {
      buffer.write(' ${failures.length} '
          'manifest${failures.length == 1 ? '' : 's'} could not be read.');
    }
    return buffer.toString();
  }
}
