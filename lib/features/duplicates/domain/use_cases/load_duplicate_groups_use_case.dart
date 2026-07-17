import '../entities/duplicate_group.dart';
import '../entities/duplicate_sensitivity.dart';
import '../entities/keeper_strategy.dart';
import '../repositories/duplicate_repository.dart';

/// Clusters the cached hashes into duplicate groups. Cheap enough to re-run on
/// every sensitivity or keeper-strategy change.
class LoadDuplicateGroupsUseCase {
  const LoadDuplicateGroupsUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<List<DuplicateGroup>> call({
    required DuplicateSensitivity sensitivity,
    required KeeperStrategy keeperStrategy,
  }) {
    return _repository.loadGroups(
      sensitivity: sensitivity,
      keeperStrategy: keeperStrategy,
    );
  }
}
