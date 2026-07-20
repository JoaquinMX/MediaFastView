/// The outcome of writing a batch of manifests under one tracked root.
///
/// Separates the three fates a folder can meet so the export can report them
/// honestly: a stale cache entry whose folder is gone ([missingFolders]) is a
/// benign skip, not the same thing as a folder that exists but could not be
/// written ([failures]).
class SidecarWriteReport {
  const SidecarWriteReport({
    this.written = const <String>[],
    this.missingFolders = const <String>[],
    this.failures = const <String>[],
  });

  /// Folders whose manifest was written successfully.
  final List<String> written;

  /// Folders that no longer exist on disk (deleted or moved outside the app),
  /// so nothing could be written there. Not an error.
  final List<String> missingFolders;

  /// Folders that exist but whose write failed (permission/IO).
  final List<String> failures;
}
