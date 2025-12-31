import '../repositories/directory_repository.dart';
import '../repositories/media_repository.dart';

/// Use case for clearing all persisted media cache entries.
class ClearMediaCacheUseCase {
  const ClearMediaCacheUseCase(
    this._mediaRepository,
    this._directoryRepository,
  );

  final MediaRepository _mediaRepository;
  final DirectoryRepository _directoryRepository;

  /// Executes the use case to remove cached media that no longer belongs to
  /// directories in the library without touching tag assignments for current
  /// media.
  Future<void> call() async {
    final directories = await _directoryRepository.getDirectories();
    final directoryIds = directories.map((directory) => directory.id).toList();

    await _mediaRepository.removeMediaNotInDirectories(directoryIds);
  }
}
