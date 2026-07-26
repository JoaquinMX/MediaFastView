import '../repositories/directory_cover_repository.dart';

/// Removes a custom cover so automatic directory preview selection resumes.
class ResetDirectoryCoverUseCase {
  const ResetDirectoryCoverUseCase(this._repository);

  final DirectoryCoverRepository _repository;

  Future<void> call(String directoryPath) {
    return _repository.removeCover(directoryPath);
  }
}
