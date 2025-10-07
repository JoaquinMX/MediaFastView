import 'app_error.dart';
import 'failure.dart';

/// Utility class for handling and converting errors throughout the application.
class ErrorHandler {
  const ErrorHandler._();

  /// Converts an [AppError] to a user-friendly message.
  static String getErrorMessage(AppError error) {
    return switch (error) {
      FileNotFoundError() => 'File not found: ${error.message}',
      FileAccessDeniedError() => 'Access denied: ${error.message}',
      FileReadError() => 'Failed to read file: ${error.message}',
      FileWriteError() => 'Failed to write file: ${error.message}',
      FileDeleteError() => 'Failed to delete file: ${error.message}',
      DirectoryNotFoundError() => 'Directory not found: ${error.message}',
      DirectoryAccessDeniedError() => 'Directory access denied: ${error.message}',
      DirectoryScanError() => 'Failed to scan directory: ${error.message}',
      DirectoryError() => 'Directory error: ${error.message}',
      PathValidationError() => 'Invalid path: ${error.message}',
      FileSystemError() => 'File system error: ${error.message}',
      PermissionError() => 'Permission denied: ${error.message}',
      ValidationError() => 'Invalid input: ${error.message}',
      PersistenceError() => 'Data storage error: ${error.message}',
      UnexpectedError() => 'An unexpected error occurred: ${error.message}',
    };
  }

  /// Converts a [Failure] to a user-friendly message.
  static String getFailureMessage(Failure failure) {
    return switch (failure) {
      NotFoundFailure() => 'Not found: ${failure.message}',
      ValidationFailure() => 'Validation failed: ${failure.message}',
      ServiceFailure() => 'Service error: ${failure.message}',
      NetworkFailure() => 'Network error: ${failure.message}',
      UnexpectedFailure() => 'An unexpected error occurred: ${failure.message}',
    };
  }

  /// Converts any exception to an [AppError].
  static AppError toAppError(Object error) {
    if (error is AppError) return error;

    return UnexpectedError(error.toString());
  }

  /// Converts any exception to a [Failure].
  static Failure toFailure(Object error) {
    if (error is Failure) return error;

    return UnexpectedFailure(error.toString());
  }
}
