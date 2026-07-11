/// Base class for application-specific errors.
/// Uses sealed classes for exhaustive error handling.
sealed class AppError {
  const AppError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Error related to file system operations.
class FileSystemError extends AppError {
  const FileSystemError(super.message);
}

/// Error for file not found operations.
class FileNotFoundError extends FileSystemError {
  const FileNotFoundError(super.message);
}

/// Error for file access denied operations.
class FileAccessDeniedError extends FileSystemError {
  const FileAccessDeniedError(super.message);
}

/// Error for file read operations.
class FileReadError extends FileSystemError {
  const FileReadError(super.message);
}

/// Error for file write operations.
class FileWriteError extends FileSystemError {
  const FileWriteError(super.message);
}

/// Error for file delete operations.
class FileDeleteError extends FileSystemError {
  const FileDeleteError(super.message);
}

/// Error for file move operations.
class FileMoveError extends FileSystemError {
  const FileMoveError(super.message);
}

/// Error for file copy operations.
class FileCopyError extends FileSystemError {
  const FileCopyError(super.message);
}

/// Error for a transfer whose destination is already taken by another item.
///
/// Carries [suggestedPath] — the name the item would take under "keep both" —
/// so the conflict prompt can show the exact result and retry in one step.
class DestinationExistsError extends FileSystemError {
  const DestinationExistsError(
    super.message, {
    required this.destinationPath,
    required this.suggestedPath,
  });

  final String destinationPath;
  final String suggestedPath;
}

/// Error for moving a directory into itself or one of its descendants.
class DestinationInsideSourceError extends FileSystemError {
  const DestinationInsideSourceError(super.message);
}

/// Error for a transfer whose destination is the item's current location.
class SamePathError extends FileSystemError {
  const SamePathError(super.message);
}

/// Error for a transfer that ran out of room on the destination volume.
class InsufficientSpaceError extends FileSystemError {
  const InsufficientSpaceError(super.message);
}

/// Error for directory operations.
class DirectoryError extends FileSystemError {
  const DirectoryError(super.message);
}

/// Error for directory not found operations.
class DirectoryNotFoundError extends DirectoryError {
  const DirectoryNotFoundError(super.message);
}

/// Error for directory access denied operations.
class DirectoryAccessDeniedError extends DirectoryError {
  const DirectoryAccessDeniedError(super.message);
}

/// Error for directory scan operations.
class DirectoryScanError extends DirectoryError {
  const DirectoryScanError(super.message);
}

/// Error for path validation operations.
class PathValidationError extends FileSystemError {
  const PathValidationError(super.message);
}

/// Error related to permission issues.
class PermissionError extends AppError {
  const PermissionError(super.message);
}

/// Error for invalid bookmark requiring user re-selection.
class BookmarkInvalidError extends PermissionError {
  const BookmarkInvalidError(super.message, this.directoryId, this.directoryPath);

  final String directoryId;
  final String directoryPath;
}

/// Error related to data validation.
class ValidationError extends AppError {
  const ValidationError(super.message);
}

/// Error related to data persistence.
class PersistenceError extends AppError {
  const PersistenceError(super.message);
}

/// Error for unexpected failures.
class UnexpectedError extends AppError {
  const UnexpectedError(super.message);
}
