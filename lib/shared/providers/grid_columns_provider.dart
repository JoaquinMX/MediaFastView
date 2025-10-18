import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

const _gridColumnsKey = 'gridColumns';
const _minColumns = 2;
const _maxColumns = 12;

class GridColumnsNotifier extends StateNotifier<int> {
  GridColumnsNotifier() : super(AppConfig.defaultGridColumns) {
    _loadColumns();
  }

  Future<void> _loadColumns() async {
    final prefs = await SharedPreferences.getInstance();
    final columns =
        prefs.getInt(_gridColumnsKey) ?? AppConfig.defaultGridColumns;
    state = columns;
  }

  Future<void> setColumns(int columns) async {
    final clamped = columns.clamp(_minColumns, _maxColumns);
    final clampedInt = clamped.toInt();
    if (clampedInt == state) {
      return;
    }
    state = clampedInt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridColumnsKey, clampedInt);
  }
}

final gridColumnsProvider = StateNotifierProvider<GridColumnsNotifier, int>((
  ref,
) {
  return GridColumnsNotifier();
});
