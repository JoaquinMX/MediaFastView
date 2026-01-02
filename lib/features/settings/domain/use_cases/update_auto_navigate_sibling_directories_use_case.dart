import '../repositories/settings_repository.dart';

/// Persists the navigation preference for sibling directories.
class UpdateAutoNavigateSiblingDirectoriesUseCase {
  const UpdateAutoNavigateSiblingDirectoriesUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveAutoNavigateSiblingDirectories(enabled);
  }
}
