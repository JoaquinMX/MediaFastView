import '../repositories/settings_repository.dart';

/// Persists whether completed media lookups should be saved to history.
class UpdateImageLookupHistoryUseCase {
  const UpdateImageLookupHistoryUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveImageLookupHistoryEnabled(enabled);
  }
}
