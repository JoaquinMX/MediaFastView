import '../repositories/directory_repository.dart';

/// Use case for clearing all directory data.
/// This removes all cached directory information from storage.
class ClearDirectoriesUseCase {
  const ClearDirectoriesUseCase(this._directoryRepository);

  final DirectoryRepository _directoryRepository;

  /// Executes the use case to clear all directory data.
  Future<void> call() async {
    await _directoryRepository.clearAllDirectories();
  }
}