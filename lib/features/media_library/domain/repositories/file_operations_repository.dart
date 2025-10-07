/// Repository interface for file operations
abstract class FileOperationsRepository {
  /// Deletes a file from the filesystem
  Future<void> deleteFile(String filePath);

  /// Deletes a directory and all its contents from the filesystem
  Future<void> deleteDirectory(String directoryPath);

  /// Validates if a path is accessible
  Future<bool> validatePath(String path);

  /// Gets file type from extension
  String getFileType(String filePath);
}
