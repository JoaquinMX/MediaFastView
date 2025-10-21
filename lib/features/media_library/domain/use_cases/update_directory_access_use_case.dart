import '../repositories/directory_repository.dart';

/// Use case responsible for persisting refreshed directory metadata after
/// recovering permissions or renewing bookmarks.
class UpdateDirectoryAccessUseCase {
  const UpdateDirectoryAccessUseCase(this._repository);

  final DirectoryRepository _repository;

  Future<void> call({
    required String directoryId,
    String? newPath,
    String? newName,
    String? bookmarkData,
  }) {
    return _repository.updateDirectoryMetadata(
      directoryId,
      path: newPath,
      name: newName,
      bookmarkData: bookmarkData,
    );
  }
}
