import '../repositories/file_operations_repository.dart';

/// Use case for validating file system paths
class ValidatePathUseCase {
  const ValidatePathUseCase(this._repository);

  final FileOperationsRepository _repository;

  /// Executes the use case to validate if a path is accessible
  Future<bool> call(String path) => _repository.validatePath(path);
}
