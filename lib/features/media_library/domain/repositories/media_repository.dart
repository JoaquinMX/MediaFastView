import '../../../../core/utils/batch_update_result.dart';
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
}
