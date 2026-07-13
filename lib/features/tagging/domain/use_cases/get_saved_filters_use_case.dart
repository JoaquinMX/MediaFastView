import '../entities/saved_filter_entity.dart';
import '../repositories/saved_filter_repository.dart';

/// Every saved filter, oldest first.
class GetSavedFiltersUseCase {
  const GetSavedFiltersUseCase(this._repository);

  final SavedFilterRepository _repository;

  Future<List<SavedFilterEntity>> call() => _repository.getFilters();
}
