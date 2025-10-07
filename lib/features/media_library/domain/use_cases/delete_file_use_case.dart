import '../repositories/file_operations_repository.dart';

/// Use case for deleting a file from the filesystem
class DeleteFileUseCase {
  const DeleteFileUseCase(this._repository);

  final FileOperationsRepository _repository;

  /// Executes the use case to delete a file
  Future<void> call(String filePath) => _repository.deleteFile(filePath);
}
