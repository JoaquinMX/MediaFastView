import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/full_screen/domain/entities/viewer_state_entity.dart';
import 'package:media_fast_view/features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import 'package:media_fast_view/features/full_screen/presentation/view_models/full_screen_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/shared/providers/video_playback_settings_provider.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';
import 'package:media_fast_view/shared/utils/tag_usage_ranker.dart';

import '../mocks.dart';
void main() {
  late MockLoadMediaForViewingUseCase loadMediaForViewingUseCase;
  late MockFavoritesViewModel favoritesViewModel;
  late MockFavoritesRepository favoritesRepository;
  late MockAssignTagUseCase assignTagUseCase;
  late MockTagLookup tagLookup;
  late MockTagCacheRefresher tagCacheRefresher;
  late FullScreenViewModel viewModel;

  const playbackSettings =
      VideoPlaybackSettings(autoplayVideos: false, loopVideos: false);

  setUp(() {
    loadMediaForViewingUseCase = MockLoadMediaForViewingUseCase();
    favoritesViewModel = MockFavoritesViewModel();
    favoritesRepository = MockFavoritesRepository();
    assignTagUseCase = MockAssignTagUseCase();
    tagLookup = MockTagLookup();
    tagCacheRefresher = MockTagCacheRefresher();

    viewModel = FullScreenViewModel(
      loadMediaForViewingUseCase,
      favoritesViewModel,
      favoritesRepository,
      assignTagUseCase,
      tagLookup,
      tagCacheRefresher,
      playbackSettings,
      tagUsageRanker: const TagUsageRanker(limit: 10),
    );
  });

  test('toggleTagOnCurrentMedia adds tag and refreshes caches', () async {
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
    final tag = TagEntity(
      id: 'tag-1',
      name: 'Favorite',
      color: 0xFF0000FF,
      createdAt: DateTime(2023, 1, 1),
    );

    viewModel.state = FullScreenLoaded(
      mediaList: [media],
      currentIndex: 0,
      isPlaying: false,
      isMuted: false,
      isLooping: false,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      isFavorite: false,
      currentMediaTags: const <TagEntity>[],
      shortcutTags: const <TagEntity>[],
    );

    when(assignTagUseCase.assignTagToMedia(media.id, tag))
        .thenAnswer((_) async {});
    when(tagLookup.getTagsByIds(['tag-1']))
        .thenAnswer((_) async => [tag]);
    when(tagLookup.refresh()).thenAnswer((_) async {});
    when(tagCacheRefresher.refresh()).thenAnswer((_) async {});

    final result = await viewModel.toggleTagOnCurrentMedia(tag);

    expect(result.outcome, TagMutationOutcome.added);
    final updatedState = viewModel.state as FullScreenLoaded;
    expect(updatedState.currentMedia.tagIds, ['tag-1']);
    expect(updatedState.currentMediaTags, [tag]);
    expect(updatedState.shortcutTags, [tag]);

    verify(assignTagUseCase.assignTagToMedia(media.id, tag)).called(1);
    verify(tagLookup.refresh()).called(1);
    verify(tagCacheRefresher.refresh()).called(1);
  });

  test('toggleTagOnCurrentMedia removes tag and refreshes caches', () async {
    final tag = TagEntity(
      id: 'tag-1',
      name: 'Favorite',
      color: 0xFF0000FF,
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

    viewModel.state = FullScreenLoaded(
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
    );

    when(assignTagUseCase.removeTagFromMedia(media.id, tag))
        .thenAnswer((_) async {});
    when(tagLookup.getTagsByIds(const <String>[]))
        .thenAnswer((_) async => const <TagEntity>[]);
    when(tagLookup.refresh()).thenAnswer((_) async {});
    when(tagCacheRefresher.refresh()).thenAnswer((_) async {});

    final result = await viewModel.toggleTagOnCurrentMedia(tag);

    expect(result.outcome, TagMutationOutcome.removed);
    final updatedState = viewModel.state as FullScreenLoaded;
    expect(updatedState.currentMedia.tagIds, isEmpty);
    expect(updatedState.currentMediaTags, isEmpty);
    expect(updatedState.shortcutTags, isEmpty);

    verify(assignTagUseCase.removeTagFromMedia(media.id, tag)).called(1);
    verify(tagLookup.refresh()).called(1);
    verify(tagCacheRefresher.refresh()).called(1);
  });

  test('setTagsForCurrentMedia replaces tags and reports changes', () async {
    final originalTag = TagEntity(
      id: 'tag-1',
      name: 'Original',
      color: 0xFF0000FF,
      createdAt: DateTime(2023, 1, 1),
    );
    final replacementTag = TagEntity(
      id: 'tag-2',
      name: 'Replacement',
      color: 0xFF00FF00,
      createdAt: DateTime(2023, 6, 1),
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

    viewModel.state = FullScreenLoaded(
      mediaList: [media],
      currentIndex: 0,
      isPlaying: false,
      isMuted: false,
      isLooping: false,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      isFavorite: false,
      currentMediaTags: [originalTag],
      shortcutTags: [originalTag],
    );

    when(assignTagUseCase.setTagsForMedia(['media-1'], ['tag-2', 'tag-1']))
        .thenAnswer((_) async {});
    when(tagLookup.getTagsByIds(any)).thenAnswer((invocation) async {
      final ids = List<String>.from(invocation.positionalArguments.first);
      if (ids.length == 2 && ids.first == 'tag-2') {
        return [replacementTag, originalTag];
      }
      if (ids.length == 2 && ids.first == 'tag-1') {
        return [originalTag, replacementTag];
      }
      return const <TagEntity>[];
    });
    when(tagLookup.refresh()).thenAnswer((_) async {});
    when(tagCacheRefresher.refresh()).thenAnswer((_) async {});

    final result =
        await viewModel.setTagsForCurrentMedia(['tag-2', 'tag-1', 'tag-2']);

    expect(result.addedCount, 1);
    expect(result.removedCount, 0);

    final updatedState = viewModel.state as FullScreenLoaded;
    expect(updatedState.currentMedia.tagIds, ['tag-2', 'tag-1']);
    expect(updatedState.currentMediaTags, [replacementTag, originalTag]);
    expect(updatedState.shortcutTags, [originalTag, replacementTag]);

    verify(assignTagUseCase.setTagsForMedia(['media-1'], ['tag-2', 'tag-1']))
        .called(1);
    verify(tagLookup.refresh()).called(1);
    verify(tagCacheRefresher.refresh()).called(1);
  });
}
