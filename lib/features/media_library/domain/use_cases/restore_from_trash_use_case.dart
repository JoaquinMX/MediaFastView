import '../entities/trashed_item_entity.dart';
import '../repositories/file_operations_repository.dart';

/// Use case for restoring items from the reversible trash.
class RestoreFromTrashUseCase {
  const RestoreFromTrashUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<void> call(
    List<TrashedItemEntity> items, {
    Map<String, String?>? bookmarkDataMap,
  }) {
    return _repository.restoreFromTrash(
      items,
      bookmarkDataMap: bookmarkDataMap,
    );
  }
}
