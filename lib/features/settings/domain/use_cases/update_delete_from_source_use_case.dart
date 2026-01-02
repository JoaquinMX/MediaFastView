import '../repositories/settings_repository.dart';

/// Persists the delete-from-source preference.
class UpdateDeleteFromSourceUseCase {
  const UpdateDeleteFromSourceUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveDeleteFromSourceEnabled(enabled);
  }
}
