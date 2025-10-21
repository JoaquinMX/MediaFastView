import '../../../../core/utils/batch_update_result.dart';
import '../entities/directory_entity.dart';

/// Repository interface for directory operations.
/// Provides methods for managing directories in the media library.
abstract class DirectoryRepository {
  /// Retrieves all directories.
  Future<List<DirectoryEntity>> getDirectories();

  /// Retrieves a directory by its ID.
  Future<DirectoryEntity?> getDirectoryById(String id);

  /// Adds a new directory.
  /// [silent] if true, skips recovery dialogs for bookmark failures (used for drag-and-drop).
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false});

  /// Removes a directory by its ID.
  Future<void> removeDirectory(String id);

  /// Searches directories by query string.
  Future<List<DirectoryEntity>> searchDirectories(String query);

  /// Filters directories by tag IDs.
  Future<List<DirectoryEntity>> filterDirectoriesByTags(List<String> tagIds);

  /// Updates the tags for a directory.
  Future<void> updateDirectoryTags(String directoryId, List<String> tagIds);

  /// Replaces the tag collections for multiple directories in a single
  /// operation. Implementations should persist the updates atomically when
  /// possible to avoid partial writes.
  Future<BatchUpdateResult> updateDirectoryTagsBatch(
    Map<String, List<String>> directoryTags,
  );

  /// Updates the bookmark data for a directory.
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData);

  /// Updates persisted metadata for a directory, allowing callers to refresh
  /// the stored path, display name, and bookmark in a single operation.
  Future<void> updateDirectoryMetadata(
    String directoryId, {
    String? path,
    String? name,
    String? bookmarkData,
  });

  /// Clears all stored directory data.
  Future<void> clearAllDirectories();
}
