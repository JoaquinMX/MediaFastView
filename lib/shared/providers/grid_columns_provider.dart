import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'repository_providers.dart';

const _gridColumnsKey = 'gridColumns';
const _minColumns = 2;
const _maxColumns = 12;

class GridColumnsNotifier extends StateNotifier<int> {
  GridColumnsNotifier(this._sharedPreferences)
      : super(
          _sharedPreferences.getInt(_gridColumnsKey) ??
              AppConfig.defaultGridColumns,
        );

  final SharedPreferences _sharedPreferences;

  void setColumns(int columns) {
    final clamped = columns.clamp(_minColumns, _maxColumns);
    final clampedInt = clamped is int ? clamped : clamped.toInt();
    if (clampedInt == state) {
      return;
    }
    state = clampedInt;
    _sharedPreferences.setInt(_gridColumnsKey, clampedInt);
  }
}

final gridColumnsProvider =
    StateNotifierProvider<GridColumnsNotifier, int>((ref) {
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  return GridColumnsNotifier(sharedPreferences);
});
