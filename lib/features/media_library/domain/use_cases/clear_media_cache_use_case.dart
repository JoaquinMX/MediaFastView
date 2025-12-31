import '../repositories/media_repository.dart';

/// Use case for clearing all persisted media cache entries.
class ClearMediaCacheUseCase {
  const ClearMediaCacheUseCase(this._mediaRepository);

  final MediaRepository _mediaRepository;

  /// Executes the use case to wipe cached media across directories.
  Future<void> call() {
    return _mediaRepository.clearAllMedia();
  }
}
