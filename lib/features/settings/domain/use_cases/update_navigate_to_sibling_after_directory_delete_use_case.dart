import '../repositories/settings_repository.dart';

/// Persists the post-delete navigation preference for directories.
class UpdateNavigateToSiblingAfterDirectoryDeleteUseCase {
  const UpdateNavigateToSiblingAfterDirectoryDeleteUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(bool enabled) {
    return _repository.saveNavigateToSiblingAfterDirectoryDelete(enabled);
  }
}
