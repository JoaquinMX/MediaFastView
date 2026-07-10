/// Repository interface for file operations
abstract class FileOperationsRepository {
  /// Deletes a file from the filesystem.
  ///
  /// [bookmarkData] is the security-scoped bookmark of the enclosing tracked
  /// directory, used to gain sandboxed write access on macOS.
  Future<void> deleteFile(String filePath, {String? bookmarkData});

  /// Deletes a directory and all its contents from the filesystem.
  ///
  /// [bookmarkData] is the security-scoped bookmark of the enclosing tracked
  /// directory, used to gain sandboxed write access on macOS.
  Future<void> deleteDirectory(String directoryPath, {String? bookmarkData});

  /// Validates if a path is accessible
  Future<bool> validatePath(String path);

  /// Gets file type from extension
  String getFileType(String filePath);
}
