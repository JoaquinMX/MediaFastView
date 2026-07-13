import '../repositories/saved_filter_repository.dart';

class DeleteSavedFilterUseCase {
  const DeleteSavedFilterUseCase(this._repository);

  final SavedFilterRepository _repository;

  Future<void> call(String id) => _repository.deleteFilter(id);
}
