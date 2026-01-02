import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Use case for loading persisted application settings.
class GetAppSettingsUseCase {
  const GetAppSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppSettings> call() {
    return _repository.loadSettings();
  }
}
