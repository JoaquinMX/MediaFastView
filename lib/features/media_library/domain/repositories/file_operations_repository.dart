import '../../../../core/services/file_transfer_result.dart';

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

  /// Moves an item into [destinationDirectoryPath], keeping its name.
  ///
  /// A transfer touches two locations, so it needs the bookmark covering the
  /// source *and* the one covering the destination.
  ///
  /// Throws [DestinationExistsError] when the destination is taken and
  /// [conflictStrategy] is [ConflictStrategy.fail].
  Future<FileTransferResult> moveItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  });

  /// Copies an item into [destinationDirectoryPath], keeping its name.
  ///
  /// The copy is given a fresh modification time, so it takes on an identity of
  /// its own rather than colliding with its source.
  Future<FileTransferResult> copyItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  });

  /// Validates if a path is accessible
  Future<bool> validatePath(String path);

  /// Gets file type from extension
  String getFileType(String filePath);
}
