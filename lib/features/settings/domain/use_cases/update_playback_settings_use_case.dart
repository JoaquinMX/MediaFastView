import '../entities/playback_settings.dart';
import '../repositories/settings_repository.dart';

/// Persists updated playback preferences.
class UpdatePlaybackSettingsUseCase {
  const UpdatePlaybackSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(PlaybackSettings settings) {
    return _repository.savePlaybackSettings(settings);
  }
}
