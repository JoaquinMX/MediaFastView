import '../entities/trashed_item_entity.dart';
import '../repositories/file_operations_repository.dart';

/// Use case for moving items to the reversible trash.
class MoveToTrashUseCase {
  const MoveToTrashUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<List<TrashedItemEntity>> call(
    List<String> paths, {
    Map<String, String?>? bookmarkDataMap,
    String? trashDirectory,
  }) {
    return _repository.moveToTrash(
      paths,
      bookmarkDataMap: bookmarkDataMap,
      trashDirectory: trashDirectory,
    );
  }
}
