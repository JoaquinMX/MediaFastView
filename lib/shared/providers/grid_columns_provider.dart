import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';

class GridColumnsNotifier extends StateNotifier<int> {
  GridColumnsNotifier() : super(AppConfig.gridColumns);

  void setColumns(int columns) {
    final clamped = columns.clamp(1, 12);
    if (clamped == state) {
      return;
    }
    state = clamped;
    AppConfig.gridColumns = clamped;
  }
}

final gridColumnsProvider =
    StateNotifierProvider<GridColumnsNotifier, int>(GridColumnsNotifier.new);
