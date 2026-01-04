import 'package:flutter/material.dart';

import 'color_scheme.dart';

/// Centralized theme configuration for the app.
class AppTheme {
  const AppTheme._();

  /// Light theme using an accessible color scheme for light mode.
  static ThemeData get lightTheme => ThemeData(
        colorScheme: AppColorScheme.light,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      );

  /// Dark theme with high contrast values for readability.
  static ThemeData get darkTheme => ThemeData(
        colorScheme: AppColorScheme.dark,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
      );
}
