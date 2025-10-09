import '../entities/file_rename_request.dart';
import '../entities/trashed_item_entity.dart';

/// Repository interface for file operations
abstract class FileOperationsRepository {
  /// Deletes a file from the filesystem
  Future<void> deleteFile(String filePath, {String? bookmarkData});

  /// Deletes a directory and all its contents from the filesystem
  Future<void> deleteDirectory(String directoryPath, {String? bookmarkData});

  /// Validates if a path is accessible
  Future<bool> validatePath(String path);

  /// Gets file type from extension
  String getFileType(String filePath);

  /// Renames multiple files or directories in bulk.
  Future<List<String>> bulkRename(
    List<FileRenameRequest> renameRequests, {
    Map<String, String?>? bookmarkDataMap,
  });

  /// Moves multiple items to a destination directory.
  Future<List<String>> moveToFolder(
    List<String> paths,
    String destinationDirectory, {
    Map<String, String?>? bookmarkDataMap,
    bool createIfMissing = true,
  });

  /// Moves multiple items to a reversible trash location.
  Future<List<TrashedItemEntity>> moveToTrash(
    List<String> paths, {
    Map<String, String?>? bookmarkDataMap,
    String? trashDirectory,
  });

  /// Restores trashed items back to their original locations.
  Future<void> restoreFromTrash(
    List<TrashedItemEntity> items, {
    Map<String, String?>? bookmarkDataMap,
  });
}
