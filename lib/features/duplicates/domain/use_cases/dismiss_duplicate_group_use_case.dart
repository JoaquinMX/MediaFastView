import '../entities/duplicate_group.dart';
import '../repositories/duplicate_repository.dart';

/// Marks a group as "not duplicates" so it stops appearing in results.
class DismissDuplicateGroupUseCase {
  const DismissDuplicateGroupUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<void> call(DuplicateGroup group) {
    return _repository.dismissGroup(group.signature);
  }
}
