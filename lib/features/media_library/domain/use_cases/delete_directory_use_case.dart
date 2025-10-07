import '../repositories/file_operations_repository.dart';

/// Use case for deleting a directory and all its contents from the filesystem
class DeleteDirectoryUseCase {
  const DeleteDirectoryUseCase(this._repository);

  final FileOperationsRepository _repository;

  /// Executes the use case to delete a directory recursively
  Future<void> call(String directoryPath) =>
      _repository.deleteDirectory(directoryPath);
}
