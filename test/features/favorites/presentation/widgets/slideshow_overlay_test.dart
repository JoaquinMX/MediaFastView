import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/slideshow_view_model.dart';
import 'package:media_fast_view/features/favorites/presentation/widgets/slideshow_overlay.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';
import 'package:media_fast_view/shared/utils/tag_mutation_service.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';

class _FakeTagLookup extends TagLookup {
  _FakeTagLookup() : super(_FakeTagRepository());

  @override
  Future<List<TagEntity>> getAllTags() async => const [];
}

class _FakeTagRepository implements TagRepository {
  @override
  Future<List<TagEntity>> getTags() async => const [];

  @override
  Future<TagEntity?> getTagById(String id) async => null;

  @override
  Future<void> createTag(TagEntity tag) async {}

  @override
  Future<void> deleteTag(String id) async {}

  @override
  Future<void> clearTags() async {}

  @override
  Future<void> updateTag(TagEntity tag) async {}
}

void main() {
  final media = MediaEntity(
    id: 'id',
    path: '/image.jpg',
    name: 'Image',
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024, 1, 1),
    tagIds: const [],
    directoryId: 'dir',
    bookmarkData: null,
  );

  testWidgets('invokes callbacks for playback controls', (tester) async {
    final viewModel = SlideshowViewModel(
      [media],
      tagMutationService: TagMutationService(
        assignTagUseCase: const _FakeAssignTagUseCase(),
        tagLookup: _FakeTagLookup(),
        tagCacheRefresher: const _FakeTagCacheRefresher(),
      ),
    );

    var playPauseTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagLookupProvider.overrideWithValue(_FakeTagLookup()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SlideshowOverlay(
              state: viewModel.state,
              viewModel: viewModel,
              onClose: () {},
              onPlayPause: () {
                playPauseTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    await tester.tap(find.byTooltip('Enable loop'));
    await tester.pump();

    await tester.tap(find.byTooltip('Enable shuffle'));
    await tester.pump();

    expect(viewModel.isLooping, isTrue);
    expect(viewModel.isPlaying, isFalse);
    expect(playPauseTapped, isTrue);
  });
}

class _FakeAssignTagUseCase implements AssignTagUseCase {
  const _FakeAssignTagUseCase();

  @override
  Future<void> assignTagToMedia(String mediaId, TagEntity tag) async {}

  @override
  Future<void> removeTagFromMedia(String mediaId, TagEntity tag) async {}
}

class _FakeTagCacheRefresher implements TagCacheRefresher {
  const _FakeTagCacheRefresher();

  @override
  Future<void> refresh() async {}
}
