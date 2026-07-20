import '../../../../core/utils/batch_update_result.dart';
import '../entities/directory_media_counts.dart';
import '../entities/media_entity.dart';

/// Repository interface for media operations.
/// Provides methods for managing media items in the media library.
abstract class MediaRepository {
  /// Retrieves all media for a specific directory by path.
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  });

  /// Retrieves all media for a specific directory by ID.
  /// @deprecated Use getMediaForDirectoryPath instead for path-aware operations.
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId);

  /// Retrieves all persisted media entries without touching the filesystem.
  Future<List<MediaEntity>> getAllMedia();

  /// Aggregates cached media counts per directory without rescanning disk.
  Future<Map<String, DirectoryMediaCounts>> getDirectoryMediaCounts();

  /// Retrieves a media item by its ID.
  Future<MediaEntity?> getMediaById(String id);

  /// Filters media by tag IDs for a specific directory.
  Future<List<MediaEntity>> filterMediaByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  });

  /// Filters media by tag IDs across all directories.
  /// @deprecated Use filterMediaByTagsForDirectory for directory-specific filtering.
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds);

  /// Updates the tags for a media item.
  Future<void> updateMediaTags(String mediaId, List<String> tagIds);

  /// Replaces the tag collections for multiple media items in a single
  /// operation. Implementations should persist the updates atomically when
  /// possible to avoid partial writes.
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  );

  /// Removes all cached media entries for a directory.
  Future<void> removeMediaForDirectory(String directoryId);

  /// Removes cached media whose directories are no longer present in the
  /// library, preserving entries (and their tags) for existing directories.
  ///
  /// Prefer [pruneMissingMedia]: this matches on `directoryId`, which for media
  /// inside a subfolder is that subfolder's id rather than the library root's,
  /// so it treats perfectly valid media as orphaned.
  Future<void> removeMediaNotInDirectories(List<String> directoryIds);

  /// Removes cached entries whose file or folder is confirmed gone from disk,
  /// leaving tags and favorites intact for everything still present.
  ///
  /// Implementations must never prune an entry they could not positively verify.
  /// Returns the number of entries removed.
  Future<int> pruneMissingMedia();

  /// Re-reads every folder in the library from disk, refreshing the cache.
  ///
  /// Picks up files added, changed, or removed outside the app. Each folder's
  /// scan merges tag assignments back onto the media that survived, so tags are
  /// preserved for everything still on disk. Returns the number of folders
  /// rescanned; [onProgress] reports `(done, total)` as it goes.
  Future<int> rescanLibrary({void Function(int done, int total)? onProgress});

  /// Removes every persisted media entry, clearing cached results across
  /// directories.
  Future<void> clearAllMedia();

  /// Inserts or updates media entries in persistence.
  Future<void> upsertMedia(List<MediaEntity> media);
}
