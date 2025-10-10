import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

/// Manages the grid column count across the application and persists changes.
class GridColumnsNotifier extends StateNotifier<int> {
  GridColumnsNotifier() : super(AppConfig.gridColumns);

  /// Updates the column count and persists the new value.
  void setColumns(int columns) {
    final clampedColumns = columns.clamp(2, 12).toInt();
    if (state == clampedColumns) {
      return;
    }

    state = clampedColumns;
    AppConfig.gridColumns = clampedColumns;
  }
}

/// Provider exposing the shared grid column count.
final gridColumnsProvider =
    StateNotifierProvider<GridColumnsNotifier, int>((ref) {
  return GridColumnsNotifier();
});
