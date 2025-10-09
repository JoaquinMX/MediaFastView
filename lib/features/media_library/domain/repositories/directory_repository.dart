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

  /// Updates the bookmark data for a directory.
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData);

  /// Updates the stored path and reconciles the directory identifier when the
  /// underlying location changes.
  Future<DirectoryEntity?> updateDirectoryPathAndId(
    String directoryId,
    String newPath,
  );

  /// Clears all stored directory data.
  Future<void> clearAllDirectories();
}
