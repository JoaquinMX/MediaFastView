import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

const _minColumns = 2;
const _maxColumns = 12;

class GridColumnsNotifier extends StateNotifier<int> {
  GridColumnsNotifier() : super(AppConfig.defaultGridColumns);

  void setColumns(int columns) {
    final clamped = columns.clamp(_minColumns, _maxColumns);
    final clampedInt = clamped.toInt();
    if (clampedInt == state) {
      return;
    }
    state = clampedInt;
  }
}

final gridColumnsProvider = StateNotifierProvider<GridColumnsNotifier, int>(
  (ref) {
    return GridColumnsNotifier();
  },
);
