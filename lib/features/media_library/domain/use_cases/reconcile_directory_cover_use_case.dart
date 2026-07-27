import '../entities/directory_cover_entity.dart';
import '../repositories/directory_cover_repository.dart';

/// Removes only custom-cover selections proven missing by a successful scan.
class ReconcileDirectoryCoverUseCase {
  const ReconcileDirectoryCoverUseCase(this._repository);

  final DirectoryCoverRepository _repository;

  Future<void> call({
    required String directoryPath,
    required List<String> missingSourceFileNames,
  }) async {
    if (missingSourceFileNames.isEmpty) {
      return;
    }

    final currentCover = await _repository.getCover(directoryPath);
    if (currentCover == null || currentCover.mode != DirectoryCoverMode.media) {
      return;
    }

    final missingNames = missingSourceFileNames
        .map((fileName) => fileName.toLowerCase())
        .toSet();
    final remainingSelections = currentCover.selections
        .where(
          (selection) =>
              !missingNames.contains(selection.sourceFileName.toLowerCase()),
        )
        .toList(growable: false);
    if (remainingSelections.length == currentCover.selections.length) {
      return;
    }
    if (remainingSelections.isEmpty) {
      await _repository.removeCover(directoryPath);
      return;
    }

    await _repository.saveCover(
      DirectoryCoverEntity.selections(
        directoryPath: currentCover.directoryPath,
        selections: remainingSelections,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
