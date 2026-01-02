import '../repositories/settings_repository.dart';

/// Persists the configured delay before hiding slideshow controls.
class UpdateSlideshowControlsHideDelayUseCase {
  const UpdateSlideshowControlsHideDelayUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(Duration delay) {
    return _repository.saveSlideshowControlsHideDelay(delay);
  }
}
