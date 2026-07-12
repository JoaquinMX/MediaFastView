import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_creation_dialog.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';

import '../tag_view_model_fakes.dart';

final _beach = TagEntity(
  id: 'tag-beach',
  name: 'Beach',
  color: 0xFF2196F3,
  createdAt: DateTime(2024),
);

/// Records whether the caches were refreshed after a create.
class _SpyCacheRefresher extends TagCacheRefresher {
  _SpyCacheRefresher(super.ref);

  bool didRefresh = false;

  @override
  Future<void> refresh() async {
    didRefresh = true;
  }
}

void main() {
  late FakeTagRepository repository;
  late _SpyCacheRefresher refresher;

  Future<void> pumpDialog(
    WidgetTester tester, {
    List<TagEntity> existing = const [],
  }) async {
    repository = FakeTagRepository(existing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagViewModelProvider.overrideWith(
            (ref) => FakeTagViewModel(
              existing.isEmpty ? const TagEmpty() : TagLoaded(existing),
              repository: repository,
            ),
          ),
          tagCacheRefresherProvider.overrideWith((ref) {
            return refresher = _SpyCacheRefresher(ref);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TagCreationDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Build the lazy provider now, so `refresher` is this test's spy rather than
    // a leftover from the previous one.
    ProviderScope.containerOf(tester.element(find.byType(TagCreationDialog)))
        .read(tagCacheRefresherProvider);
  }

  Future<void> create(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextFormField), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  group('TagCreationDialog', () {
    testWidgets('creates a tag through the domain', (tester) async {
      await pumpDialog(tester);

      await create(tester, 'Seaside');

      expect(repository.tags.single.name, 'Seaside');
    });

    testWidgets('refreshes the caches after creating', (tester) async {
      // Creation used to refresh nothing, so a new tag was invisible to the
      // usage counts and to TagLookup until something else invalidated them.
      await pumpDialog(tester);

      await create(tester, 'Seaside');

      expect(refresher.didRefresh, isTrue);
    });

    testWidgets('rejects a duplicate name and persists nothing',
        (tester) async {
      await pumpDialog(tester, existing: [_beach]);

      await create(tester, 'Beach');

      expect(find.text('A tag with this name already exists'), findsOneWidget);
      expect(repository.tags, hasLength(1));
      expect(refresher.didRefresh, isFalse);
    });

    testWidgets('rejects a duplicate name whatever its case', (tester) async {
      await pumpDialog(tester, existing: [_beach]);

      await create(tester, 'bEaCh');

      expect(find.text('A tag with this name already exists'), findsOneWidget);
      expect(repository.tags, hasLength(1));
    });

    testWidgets('applies the shared name rules', (tester) async {
      await pumpDialog(tester);

      await create(tester, 'a');

      expect(
        find.text('Tag name must be at least 2 characters long'),
        findsOneWidget,
      );
      expect(repository.tags, isEmpty);
    });
  });
}
