import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_usage.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_chip.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/widgets/tag_selection_dialog.dart';

import '../tag_view_model_fakes.dart';

final _beach = TagEntity(
  id: 'tag-beach',
  name: 'Beach',
  color: 0xFF2196F3,
  createdAt: DateTime(2024, 1, 1),
);
final _family = TagEntity(
  id: 'tag-family',
  name: 'Family',
  color: 0xFF4CAF50,
  createdAt: DateTime(2024, 2, 2),
);

void main() {
  Future<
      ({
        List<TagEntity> edited,
        List<TagEntity> deleted,
        List<TagEntity> merged
      })> pumpDialog(
    WidgetTester tester, {
    required bool showEditButtons,
    bool showDeleteButtons = true,
    bool showMergeButtons = false,
    List<TagEntity>? tags,
    Map<String, TagUsage>? usage,
  }) async {
    final edited = <TagEntity>[];
    final deleted = <TagEntity>[];
    final merged = <TagEntity>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagViewModelProvider.overrideWith(
            (ref) => FakeTagViewModel(TagLoaded(tags ?? [_beach, _family])),
          ),
          // Left unresolved by default so the row renders without a subtitle —
          // the list must not block on a count.
          if (usage != null)
            tagUsageProvider.overrideWith((ref) async => usage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TagSelectionDialog<void>(
              title: 'Manage Tags',
              showEditButtons: showEditButtons,
              showDeleteButtons: showDeleteButtons,
              showMergeButtons: showMergeButtons,
              onEditTag: (context, tag) async => edited.add(tag),
              onDeleteTag: (context, tag) async => deleted.add(tag),
              onMergeTag: (context, tag) async => merged.add(tag),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (edited: edited, deleted: deleted, merged: merged);
  }

  group('TagSelectionDialog manage mode', () {
    testWidgets('lists tags as rows, not chips', (tester) async {
      // Chips have a single action slot and it is already spent on delete, so
      // manage mode has to give up the chip layout to fit an edit action.
      await pumpDialog(tester, showEditButtons: true);

      expect(find.byType(TagChip), findsNothing);
      expect(find.text('Beach'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
    });

    testWidgets('offers both an edit and a delete action per tag',
        (tester) async {
      await pumpDialog(tester, showEditButtons: true);

      expect(find.byTooltip('Edit "Beach"'), findsOneWidget);
      expect(find.byTooltip('Delete "Beach"'), findsOneWidget);
      expect(find.byTooltip('Edit "Family"'), findsOneWidget);
      expect(find.byTooltip('Delete "Family"'), findsOneWidget);
    });

    testWidgets('edit reports the tag whose pencil was pressed',
        (tester) async {
      final callbacks = await pumpDialog(tester, showEditButtons: true);

      await tester.tap(find.byTooltip('Edit "Family"'));
      await tester.pumpAndSettle();

      expect(callbacks.edited.single.id, _family.id);
      expect(callbacks.deleted, isEmpty);
    });

    testWidgets('delete still reports the right tag', (tester) async {
      final callbacks = await pumpDialog(tester, showEditButtons: true);

      await tester.tap(find.byTooltip('Delete "Beach"'));
      await tester.pumpAndSettle();

      expect(callbacks.deleted.single.id, _beach.id);
      expect(callbacks.edited, isEmpty);
    });

    testWidgets('hides the delete action when it is not offered',
        (tester) async {
      await pumpDialog(
        tester,
        showEditButtons: true,
        showDeleteButtons: false,
      );

      expect(find.byTooltip('Edit "Beach"'), findsOneWidget);
      expect(find.byTooltip('Delete "Beach"'), findsNothing);
    });
  });

  group('TagSelectionDialog usage counts', () {
    testWidgets('reports files and folders separately', (tester) async {
      // A single total would under-report: directories carry tags too.
      await pumpDialog(
        tester,
        showEditButtons: true,
        usage: {
          _beach.id: const TagUsage(mediaCount: 240, directoryCount: 3),
          _family.id: const TagUsage(mediaCount: 1),
        },
      );

      expect(find.text('240 files · 3 folders'), findsOneWidget);
      expect(find.text('1 file'), findsOneWidget);
    });

    testWidgets('calls out a tag nothing is using', (tester) async {
      await pumpDialog(
        tester,
        showEditButtons: true,
        usage: {_beach.id: TagUsage.none, _family.id: TagUsage.none},
      );

      expect(find.text('Unused'), findsNWidgets(2));
    });

    testWidgets('renders without a count rather than blocking on one',
        (tester) async {
      await pumpDialog(tester, showEditButtons: true);

      // The rows are useful without the counts, so they must not wait for them.
      expect(find.text('Beach'), findsOneWidget);
      expect(find.text('Unused'), findsNothing);
    });
  });

  group('TagSelectionDialog merge action', () {
    testWidgets('offers merge per tag and reports which one to merge away',
        (tester) async {
      final callbacks = await pumpDialog(
        tester,
        showEditButtons: true,
        showMergeButtons: true,
      );

      await tester.tap(find.byTooltip('Merge "Beach" into another tag'));
      await tester.pumpAndSettle();

      expect(callbacks.merged.single.id, _beach.id);
      expect(callbacks.edited, isEmpty);
      expect(callbacks.deleted, isEmpty);
    });

    testWidgets('hides merge when there is nothing to merge into',
        (tester) async {
      await pumpDialog(
        tester,
        showEditButtons: true,
        showMergeButtons: true,
        tags: [_beach],
      );

      expect(find.byTooltip('Merge "Beach" into another tag'), findsNothing);
      // The other actions still stand.
      expect(find.byTooltip('Edit "Beach"'), findsOneWidget);
    });
  });

  group('TagSelectionDialog other modes', () {
    testWidgets('keep their chips when editing is not enabled', (tester) async {
      // Assign / filter / bulk-assign must be untouched by the manage-mode
      // layout branch.
      await pumpDialog(tester, showEditButtons: false);

      expect(find.byType(TagChip), findsNWidgets(2));
      expect(find.byTooltip('Edit "Beach"'), findsNothing);
    });
  });
}
