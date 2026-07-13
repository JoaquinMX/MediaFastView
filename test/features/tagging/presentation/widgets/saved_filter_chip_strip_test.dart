import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/saved_filter_chip_strip.dart';

SavedFilterEntity _filter(String id, String name) {
  return SavedFilterEntity(
    id: id,
    name: name,
    definition: const SavedFilterDefinition(requiredTagIds: {'beach'}),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

final _trips = _filter('filter-trips', 'Trips 2024');
final _keepers = _filter('filter-keepers', 'Keepers');

void main() {
  late List<SavedFilterEntity> applied;
  late List<(SavedFilterEntity, SavedFilterAction)> actions;
  late int clears;

  Future<void> pumpStrip(
    WidgetTester tester, {
    List<SavedFilterEntity>? filters,
    String? appliedFilterId,
  }) async {
    applied = [];
    actions = [];
    clears = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedFilterChipStrip(
            filters: filters ?? [_trips, _keepers],
            appliedFilterId: appliedFilterId,
            onApply: applied.add,
            onClear: () => clears += 1,
            onAction: (filter, action) => actions.add((filter, action)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SavedFilterChipStrip', () {
    testWidgets('shows nothing until something is saved', (tester) async {
      await pumpStrip(tester, filters: const []);

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('lists every saved filter', (tester) async {
      await pumpStrip(tester);

      expect(find.text('Trips 2024'), findsOneWidget);
      expect(find.text('Keepers'), findsOneWidget);
    });

    testWidgets('one tap applies a filter', (tester) async {
      // The whole point of the strip: switching views is a single tap, not a
      // trip through a menu.
      await pumpStrip(tester);

      await tester.tap(find.text('Trips 2024'));
      await tester.pumpAndSettle();

      expect(applied.single.id, _trips.id);
      expect(clears, 0);
    });

    testWidgets('the applied filter reads as selected', (tester) async {
      await pumpStrip(tester, appliedFilterId: _trips.id);

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips.first.selected, isTrue);
      expect(chips.last.selected, isFalse);
    });

    testWidgets('tapping the applied filter again un-applies it',
        (tester) async {
      await pumpStrip(tester, appliedFilterId: _trips.id);

      await tester.tap(find.text('Trips 2024'));
      await tester.pumpAndSettle();

      expect(clears, 1);
      expect(applied, isEmpty);
    });

    testWidgets('long-press offers update, rename and delete', (tester) async {
      await pumpStrip(tester);

      await tester.longPress(find.text('Keepers'));
      await tester.pumpAndSettle();

      expect(find.text('Update from current filter'), findsOneWidget);
      expect(find.text('Rename…'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Rename…'));
      await tester.pumpAndSettle();

      expect(actions.single.$1.id, _keepers.id);
      expect(actions.single.$2, SavedFilterAction.rename);
    });
  });
}
