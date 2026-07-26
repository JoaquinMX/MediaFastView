import '../repositories/file_operations_repository.dart';
import '../repositories/directory_cover_repository.dart';

/// Use case for deleting a file from the filesystem
class DeleteFileUseCase {
  const DeleteFileUseCase(
    this._repository, {
    DirectoryCoverRepository? directoryCoverRepository,
  }) : _directoryCoverRepository = directoryCoverRepository;

  final FileOperationsRepository _repository;
  final DirectoryCoverRepository? _directoryCoverRepository;

  /// Executes the use case to delete a file
  Future<void> call(String filePath, {String? bookmarkData}) async {
    await _repository.deleteFile(filePath, bookmarkData: bookmarkData);
    await _directoryCoverRepository?.removeCoverForSource(filePath);
  }
}
