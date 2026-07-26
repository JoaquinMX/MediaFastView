import '../repositories/directory_repository.dart';
import '../repositories/directory_cover_repository.dart';

/// Use case for clearing all directory data.
/// This removes all cached directory information from storage.
class ClearDirectoriesUseCase {
  const ClearDirectoriesUseCase(
    this._directoryRepository, [
    this._directoryCoverRepository,
  ]);

  final DirectoryRepository _directoryRepository;
  final DirectoryCoverRepository? _directoryCoverRepository;

  /// Executes the use case to clear all directory data.
  Future<void> call() async {
    await _directoryRepository.clearAllDirectories();
    await _directoryCoverRepository?.clearCovers();
  }
}
