import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/full_screen/domain/entities/viewer_state_entity.dart';
import 'package:media_fast_view/features/full_screen/presentation/screens/full_screen_viewer_screen.dart';
import 'package:media_fast_view/features/full_screen/presentation/view_models/full_screen_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';
import 'package:media_fast_view/shared/utils/tag_usage_ranker.dart';

import '../mocks.dart';

class _FakeFullScreenViewModel extends FullScreenViewModel {
  _FakeFullScreenViewModel({
    required LoadMediaForViewingUseCase loadMediaForViewingUseCase,
    required FavoritesViewModel favoritesViewModel,
    required FavoritesRepository favoritesRepository,
    required AssignTagUseCase assignTagUseCase,
    required TagLookup tagLookup,
    required TagCacheRefresher tagCacheRefresher,
    required Map<String, TagEntity> tagCatalog,
  })  : _tagCatalog = tagCatalog,
        super(
          loadMediaForViewingUseCase,
          favoritesViewModel,
          favoritesRepository,
          assignTagUseCase,
          tagLookup,
          tagCacheRefresher,
          const VideoPlaybackSettings(autoplayVideos: false, loopVideos: false),
          tagUsageRanker: const TagUsageRanker(limit: 10),
        );

  final Map<String, TagEntity> _tagCatalog;
  TagMutationOutcome? lastOutcome;
  TagUpdateResult? lastUpdate;

  void seedState(FullScreenLoaded state) {
    this.state = state;
  }

  @override
  Future<void> initialize(
    String directoryPath, {
    String? initialMediaId,
    String? bookmarkData,
    List<MediaEntity>? mediaList,
  }) async {}

  @override
  Future<TagMutationResult> toggleTagOnCurrentMedia(TagEntity tag) async {
    final currentState = state as FullScreenLoaded;
    final media = currentState.currentMedia;
    final hasTag = media.tagIds.contains(tag.id);
    final updatedTagIds = hasTag
        ? media.tagIds.where((id) => id != tag.id).toList()
        : [...media.tagIds, tag.id];

    final updatedMedia = media.copyWith(tagIds: updatedTagIds);
    final updatedMediaList = [...currentState.mediaList];
    updatedMediaList[currentState.currentIndex] = updatedMedia;

    final updatedCurrentTags = hasTag
        ? currentState.currentMediaTags
            .where((existing) => existing.id != tag.id)
            .toList()
        : [...currentState.currentMediaTags, tag];

    final updatedShortcuts = hasTag
        ? currentState.shortcutTags
            .where((existing) => existing.id != tag.id)
            .toList()
        : [...currentState.shortcutTags, tag];

    state = currentState.copyWith(
      mediaList: updatedMediaList,
      currentMediaTags: updatedCurrentTags,
      shortcutTags: updatedShortcuts,
    );

    final outcome =
        hasTag ? TagMutationOutcome.removed : TagMutationOutcome.added;
    lastOutcome = outcome;
    return TagMutationResult(outcome);
  }

  @override
  Future<TagUpdateResult> setTagsForCurrentMedia(List<String> tagIds) async {
    final currentState = state as FullScreenLoaded;
    final media = currentState.currentMedia;
    final previousIds = media.tagIds.toSet();
    final dedupedIds = <String>[];
    for (final id in tagIds) {
      if (id.isEmpty || dedupedIds.contains(id)) {
        continue;
      }
      dedupedIds.add(id);
    }

    final updatedMedia = media.copyWith(tagIds: dedupedIds);
    final updatedMediaList = [...currentState.mediaList];
    updatedMediaList[currentState.currentIndex] = updatedMedia;

    final updatedTags = [
      for (final id in dedupedIds) _tagCatalog[id]!,
    ];

    state = currentState.copyWith(
      mediaList: updatedMediaList,
      currentMediaTags: updatedTags,
      shortcutTags: updatedTags,
    );

    final result = TagUpdateResult(
      addedCount: dedupedIds.toSet().difference(previousIds).length,
      removedCount: previousIds.difference(dedupedIds.toSet()).length,
    );
    lastUpdate = result;
    return result;
  }
}

void main() {
  testWidgets('displays tag overlay and handles chip tap', (tester) async {
    final loadMedia = MockLoadMediaForViewingUseCase();
    final favoritesViewModel = MockFavoritesViewModel();
    final favoritesRepository = MockFavoritesRepository();
    final assignTagUseCase = MockAssignTagUseCase();
    final tagLookup = MockTagLookup();
    final tagCacheRefresher = MockTagCacheRefresher();

    final tag = TagEntity(
      id: 'tag-1',
      name: 'Tag 1',
      color: 0xFF2196F3,
      createdAt: DateTime(2023, 1, 1),
    );

    final media = MediaEntity(
      id: 'media-1',
      path: '/tmp/media.jpg',
      name: 'media.jpg',
      type: MediaType.image,
      size: 0,
      lastModified: DateTime(2024, 1, 1),
      tagIds: const ['tag-1'],
      directoryId: 'dir-1',
    );

    final viewModel = _FakeFullScreenViewModel(
      loadMediaForViewingUseCase: loadMedia,
      favoritesViewModel: favoritesViewModel,
      favoritesRepository: favoritesRepository,
      assignTagUseCase: assignTagUseCase,
      tagLookup: tagLookup,
      tagCacheRefresher: tagCacheRefresher,
      tagCatalog: {'tag-1': tag},
    )..seedState(
        FullScreenLoaded(
          mediaList: [media],
          currentIndex: 0,
          isPlaying: false,
          isMuted: false,
          isLooping: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isFavorite: false,
          currentMediaTags: [tag],
          shortcutTags: [tag],
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fullScreenViewModelProvider.overrideWith((ref) => viewModel),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FullScreenViewerScreen(directoryPath: 'dir-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tag 1'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);

    await tester.tap(find.text('Tag 1'));
    await tester.pumpAndSettle();

    expect(viewModel.lastOutcome, TagMutationOutcome.removed);
    expect(find.text('Removed "Tag 1"'), findsOneWidget);
  });

  testWidgets('keyboard shortcut toggles top-ranked tag', (tester) async {
    final loadMedia = MockLoadMediaForViewingUseCase();
    final favoritesViewModel = MockFavoritesViewModel();
    final favoritesRepository = MockFavoritesRepository();
    final assignTagUseCase = MockAssignTagUseCase();
    final tagLookup = MockTagLookup();
    final tagCacheRefresher = MockTagCacheRefresher();

    final tag = TagEntity(
      id: 'tag-1',
      name: 'Tag 1',
      color: 0xFF2196F3,
      createdAt: DateTime(2023, 1, 1),
    );

    final media = MediaEntity(
      id: 'media-1',
      path: '/tmp/media.jpg',
      name: 'media.jpg',
      type: MediaType.image,
      size: 0,
      lastModified: DateTime(2024, 1, 1),
      tagIds: const <String>[],
      directoryId: 'dir-1',
    );

    final viewModel = _FakeFullScreenViewModel(
      loadMediaForViewingUseCase: loadMedia,
      favoritesViewModel: favoritesViewModel,
      favoritesRepository: favoritesRepository,
      assignTagUseCase: assignTagUseCase,
      tagLookup: tagLookup,
      tagCacheRefresher: tagCacheRefresher,
      tagCatalog: {'tag-1': tag},
    )..seedState(
        FullScreenLoaded(
          mediaList: [media],
          currentIndex: 0,
          isPlaying: false,
          isMuted: false,
          isLooping: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isFavorite: false,
          currentMediaTags: const <TagEntity>[],
          shortcutTags: [tag],
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fullScreenViewModelProvider.overrideWith((ref) => viewModel),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FullScreenViewerScreen(directoryPath: 'dir-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(viewModel.lastOutcome, TagMutationOutcome.added);
    expect(find.text('Added "Tag 1"'), findsOneWidget);
  });
}
