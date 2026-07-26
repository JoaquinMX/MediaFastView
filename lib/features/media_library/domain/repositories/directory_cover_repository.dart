import '../entities/directory_cover_entity.dart';

/// Persists profile-specific custom directory covers.
abstract interface class DirectoryCoverRepository {
  Future<DirectoryCoverEntity?> getCover(String directoryPath);

  Future<void> saveCover(DirectoryCoverEntity cover);

  Future<void> removeCover(String directoryPath);

  /// Updates or removes covers affected by moving one selected media file.
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  });

  /// Removes a cover when its selected source file is deleted.
  Future<void> removeCoverForSource(String sourcePath);

  /// Rewrites covers owned by a directory tree after the tree moves.
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  });

  /// Removes covers for [directoryPath] and every directory below it.
  Future<void> removeCoversUnder(String directoryPath);

  /// Removes every cover owned by the repository's profile.
  Future<void> clearCovers();
}
