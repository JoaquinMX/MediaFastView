import '../repositories/media_repository.dart';

/// Removes cached media entries whose file or folder no longer exists on disk.
///
/// Named "clear" for historical reasons, but it is a **reconciliation, not a
/// wipe**: tags and favorites are kept for every file still present. It used to
/// prune by comparing each row's `directoryId` against the library roots, which
/// quietly deleted all media living in subfolders — their `directoryId` is the
/// subfolder's, not the root's — and took their tag assignments with it.
class ClearMediaCacheUseCase {
  const ClearMediaCacheUseCase(this._mediaRepository);

  final MediaRepository _mediaRepository;

  /// Returns the number of stale entries removed.
  Future<int> call() => _mediaRepository.pruneMissingMedia();
}
