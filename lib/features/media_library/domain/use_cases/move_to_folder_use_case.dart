import '../repositories/file_operations_repository.dart';

/// Use case for moving multiple items to a destination folder.
class MoveToFolderUseCase {
  const MoveToFolderUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<List<String>> call(
    List<String> paths,
    String destinationDirectory, {
    Map<String, String?>? bookmarkDataMap,
    bool createIfMissing = true,
  }) {
    return _repository.moveToFolder(
      paths,
      destinationDirectory,
      bookmarkDataMap: bookmarkDataMap,
      createIfMissing: createIfMissing,
    );
  }
}
