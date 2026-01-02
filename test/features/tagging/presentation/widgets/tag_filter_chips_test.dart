import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/selectable_tag_chip_strip.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_filter_chips.dart';

class _FakeTagNotifier extends StateNotifier<TagState> {
  _FakeTagNotifier(super.state);
}

void main() {
  final tags = [
    TagEntity(
      id: 'tag-1',
      name: 'Tag One',
      color: 0xFF00FF00,
      createdAt: DateTime(2024, 1, 1),
    ),
    TagEntity(
      id: 'tag-2',
      name: 'Tag Two',
      color: 0xFF0000FF,
      createdAt: DateTime(2024, 1, 2),
    ),
  ];

  testWidgets('TagFilterChips toggles selection and clears via All chip',
      (tester) async {
    final selections = <List<String>>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagViewModelProvider.overrideWith(
            (ref) => _FakeTagNotifier(TagLoaded(tags)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TagFilterChips(
              selectedTagIds: const [],
              onSelectionChanged: selections.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tag One'));
    await tester.pumpAndSettle();

    expect(selections.single, equals(['tag-1']));

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(selections.last, isEmpty);
  });

  testWidgets('SelectableTagChipStrip exposes overflow and selection callbacks',
      (tester) async {
    bool overflowTapped = false;
    List<String>? latestSelection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableTagChipStrip(
            tags: tags,
            selectedTagIds: const [],
            onSelectionChanged: (selection) => latestSelection = selection,
            maxChipsToShow: 1,
            onOverflowPressed: () => overflowTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    expect(overflowTapped, isTrue);

    await tester.tap(find.text('Tag One'));
    await tester.pumpAndSettle();

    expect(latestSelection, equals(['tag-1']));
  });
}
