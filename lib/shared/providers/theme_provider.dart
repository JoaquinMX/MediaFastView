import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing application theme mode.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

/// Notifier for managing theme mode state.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  void setThemeMode(ThemeMode themeMode) {
    debugPrint('ThemeProvider: Setting theme mode from $state to $themeMode');
    state = themeMode;
    debugPrint('ThemeProvider: Theme mode set to $themeMode');
  }
}
