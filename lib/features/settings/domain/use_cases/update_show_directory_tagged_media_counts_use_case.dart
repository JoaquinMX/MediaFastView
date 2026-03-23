import '../repositories/settings_repository.dart';

/// Persists the directory card tagged media count preference.
class UpdateShowDirectoryTaggedMediaCountsUseCase {
  const UpdateShowDirectoryTaggedMediaCountsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveShowDirectoryTaggedMediaCounts(enabled);
  }
}
