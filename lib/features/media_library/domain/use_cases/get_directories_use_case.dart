import '../entities/directory_entity.dart';
import '../repositories/directory_repository.dart';

/// Use case for retrieving all directories.
class GetDirectoriesUseCase {
  const GetDirectoriesUseCase(this._repository);

  final DirectoryRepository _repository;

  /// Executes the use case to get all directories.
  Future<List<DirectoryEntity>> call() => _repository.getDirectories();
}
