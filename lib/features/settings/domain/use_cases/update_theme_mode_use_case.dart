import 'package:flutter/material.dart';

import '../repositories/settings_repository.dart';

/// Persists the user's preferred theme mode.
class UpdateThemeModeUseCase {
  const UpdateThemeModeUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(ThemeMode themeMode) {
    return _repository.saveThemeMode(themeMode);
  }
}
