import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/tag_validation.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_edit_dialog.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';

import '../tag_view_model_fakes.dart';

const int _blue = 0xFF2196F3;
const int _pink = 0xFFE91E63;

TagEntity _tag({String id = 'tag-beach', String name = 'Beach', int color = _blue}) {
  return TagEntity(
    id: id,
    name: name,
    color: color,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Records whether the caches were refreshed after a save.
class _SpyCacheRefresher extends TagCacheRefresher {
  _SpyCacheRefresher(super.ref);

  bool didRefresh = false;

  @override
  Future<void> refresh() async {
    didRefresh = true;
  }
}

void main() {
  late FakeTagViewModel viewModel;
  late _SpyCacheRefresher refresher;

  Future<void> pumpDialog(WidgetTester tester, TagEntity tag,
      {List<TagEntity>? allTags}) async {
    viewModel = FakeTagViewModel(TagLoaded(allTags ?? [tag]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagViewModelProvider.overrideWith((ref) => viewModel),
          tagCacheRefresherProvider.overrideWith((ref) {
            return refresher = _SpyCacheRefresher(ref);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: TagEditDialog(tag: tag)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The provider is lazy and the dialog only reads it once a save gets past
    // validation. Build it now so `refresher` is this test's spy rather than a
    // leftover from the previous one — otherwise "did not refresh" assertions
    // would read a stale instance and pass for the wrong reason.
    ProviderScope.containerOf(tester.element(find.byType(TagEditDialog)))
        .read(tagCacheRefresherProvider);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('TagEditDialog', () {
    testWidgets('opens prefilled with the tag it is editing', (tester) async {
      await pumpDialog(tester, _tag());

      expect(find.text('Edit Tag'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        'Beach',
      );
    });

    testWidgets('renames the tag', (tester) async {
      final tag = _tag();
      await pumpDialog(tester, tag);

      await tester.enterText(find.byType(TextFormField), 'Seaside');
      await save(tester);

      expect(viewModel.updatedTags, hasLength(1));
      expect(viewModel.updatedTags.single.tag.id, tag.id);
      expect(viewModel.updatedTags.single.name, 'Seaside');
      expect(viewModel.updatedTags.single.color, _blue);
    });

    testWidgets('saves a colour-only change, leaving the name alone',
        (tester) async {
      // The self-collision case: the name has not changed, so the duplicate
      // check must not trip over the tag's own row.
      await pumpDialog(tester, _tag());

      await tester.tap(find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            (widget.decoration as BoxDecoration?)?.color == const Color(_pink),
      ));
      await tester.pumpAndSettle();
      await save(tester);

      expect(viewModel.updatedTags, hasLength(1));
      expect(viewModel.updatedTags.single.name, 'Beach');
      expect(viewModel.updatedTags.single.color, _pink);
    });

    testWidgets('refreshes the caches after saving', (tester) async {
      // Otherwise the full-screen and slideshow overlays keep resolving the tag
      // through a stale TagLookup and show its old name until restart.
      await pumpDialog(tester, _tag());

      await tester.enterText(find.byType(TextFormField), 'Seaside');
      await save(tester);

      expect(refresher.didRefresh, isTrue);
    });

    testWidgets('rejects a name already taken by another tag', (tester) async {
      final beach = _tag();
      final family = _tag(id: 'tag-family', name: 'Family');
      await pumpDialog(tester, beach, allTags: [beach, family]);

      await tester.enterText(find.byType(TextFormField), 'Family');
      await save(tester);

      expect(find.text('A tag with this name already exists'), findsOneWidget);
      expect(viewModel.updatedTags, isEmpty);
      expect(refresher.didRefresh, isFalse);
    });

    testWidgets('accepts a case-only rename of the same tag', (tester) async {
      final beach = _tag();
      await pumpDialog(tester, beach, allTags: [beach]);

      await tester.enterText(find.byType(TextFormField), 'BEACH');
      await save(tester);

      expect(find.text('A tag with this name already exists'), findsNothing);
      expect(viewModel.updatedTags.single.name, 'BEACH');
    });

    testWidgets('rejects a name that breaks the shared rules', (tester) async {
      await pumpDialog(tester, _tag());

      await tester.enterText(find.byType(TextFormField), 'a');
      await save(tester);

      expect(viewModel.updatedTags, isEmpty);
      expect(
        find.text('Tag name must be at least 2 characters long'),
        findsOneWidget,
      );
    });

    testWidgets('does not close or refresh when the save fails', (tester) async {
      await pumpDialog(tester, _tag());
      viewModel.updateFailure = const TagValidationException('nope');

      await tester.enterText(find.byType(TextFormField), 'Seaside');
      await save(tester);

      expect(find.text('nope'), findsOneWidget);
      expect(refresher.didRefresh, isFalse);
    });
  });
}
