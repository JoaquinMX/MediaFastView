import 'package:media_fast_view/features/settings/domain/repositories/settings_repository.dart';

/// Persists whether generated thumbnails should be retained on disk.
class UpdateThumbnailDiskCacheUseCase {
  const UpdateThumbnailDiskCacheUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveThumbnailDiskCacheEnabled(enabled);
  }
}
