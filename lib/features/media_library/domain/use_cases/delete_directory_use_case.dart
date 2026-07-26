import '../repositories/file_operations_repository.dart';
import '../repositories/directory_cover_repository.dart';

/// Use case for deleting a directory and all its contents from the filesystem
class DeleteDirectoryUseCase {
  const DeleteDirectoryUseCase(
    this._repository, {
    DirectoryCoverRepository? directoryCoverRepository,
  }) : _directoryCoverRepository = directoryCoverRepository;

  final FileOperationsRepository _repository;
  final DirectoryCoverRepository? _directoryCoverRepository;

  /// Executes the use case to delete a directory recursively
  Future<void> call(String directoryPath, {String? bookmarkData}) async {
    await _repository.deleteDirectory(
      directoryPath,
      bookmarkData: bookmarkData,
    );
    await _directoryCoverRepository?.removeCoversUnder(directoryPath);
  }
}
