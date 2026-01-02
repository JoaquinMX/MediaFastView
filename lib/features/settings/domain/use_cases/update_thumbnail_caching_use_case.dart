import '../repositories/settings_repository.dart';

/// Persists the thumbnail caching preference.
class UpdateThumbnailCachingUseCase {
  const UpdateThumbnailCachingUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveThumbnailCachingEnabled(enabled);
  }
}
