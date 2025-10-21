import '../../../../shared/utils/directory_id_utils.dart';
import '../repositories/directory_repository.dart';

/// Coordinates persistence of recovered directory access information.
class UpdateDirectoryAccessUseCase {
  const UpdateDirectoryAccessUseCase(this._repository);

  final DirectoryRepository _repository;

  /// Persists a new filesystem location and optional bookmark for the
  /// directory that was previously stored at [previousPath].
  Future<void> updateLocation({
    required String previousPath,
    required String updatedPath,
    String? bookmarkData,
  }) async {
    final previousId = generateDirectoryId(previousPath);
    await _repository.updateDirectoryLocation(
      previousId,
      updatedPath,
      bookmarkData: bookmarkData,
    );
  }

  /// Updates the bookmark associated with [directoryPath] without modifying
  /// its stored location. When [bookmarkData] is null the persisted bookmark is
  /// cleared.
  Future<void> updateBookmark({
    required String directoryPath,
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    await _repository.updateDirectoryBookmark(directoryId, bookmarkData);
  }
}
