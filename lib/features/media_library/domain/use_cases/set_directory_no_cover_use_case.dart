import 'package:path/path.dart' as p;

import '../entities/directory_cover_entity.dart';
import '../repositories/directory_cover_repository.dart';

/// Persists an explicit choice to display a directory without a cover.
class SetDirectoryNoCoverUseCase {
  const SetDirectoryNoCoverUseCase(this._repository);

  final DirectoryCoverRepository _repository;

  Future<void> call(String directoryPath) {
    return _repository.saveCover(
      DirectoryCoverEntity.none(
        directoryPath: p.normalize(directoryPath),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
