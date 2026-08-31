import '../../../../core/models/media_lookup_mode.dart';
import '../repositories/settings_repository.dart';

/// Persists the lookup mode used for the next media lookup.
class UpdateMediaLookupModeUseCase {
  const UpdateMediaLookupModeUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(MediaLookupMode mode) {
    return _repository.saveMediaLookupMode(mode);
  }
}
