import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/selectable_tag_chip_strip.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_filter_chips.dart';

import '../tag_view_model_fakes.dart';

/// No-op selection callback for tests that don't care about selection events
/// (e.g. loading-state assertions).
void _ignoreSelection(List<String> _) {}

typedef _FakeTagViewModel = FakeTagViewModel;

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

    // Verify overflow indicator shown when tags exceed maxChipsToShow
    expect(find.text('+1'), findsOneWidget);

    // Tap overflow indicator
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();

    expect(overflowTapped, isTrue);

    // Select a tag from the visible chip
    await tester.tap(find.text('Tag One'));
    await tester.pumpAndSettle();

    expect(latestSelection, equals(['tag-1']));
  });

  testWidgets('TagFilterChips handles loading state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagViewModelProvider.overrideWith(
            (ref) => _FakeTagViewModel(const TagLoading()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TagFilterChips(
              selectedTagIds: const [],
              onSelectionChanged: _ignoreSelection,
            ),
          ),
        ),
      ),
    );

    // Should show loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SelectableTagChipStrip), findsNothing);
  });
}
