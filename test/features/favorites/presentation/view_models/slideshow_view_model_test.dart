import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/slideshow_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/shared/utils/tag_mutation_service.dart';

class _MockTagMutationService extends Mock implements TagMutationService {}

void main() {
  late _MockTagMutationService tagMutationService;
  late List<MediaEntity> media;

  setUp(() {
    tagMutationService = _MockTagMutationService();
    media = [
      MediaEntity(
        id: 'image-1',
        path: '/image.jpg',
        name: 'Image',
        type: MediaType.image,
        size: 1,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const [],
        directoryId: 'dir',
        bookmarkData: null,
      ),
      MediaEntity(
        id: 'video-1',
        path: '/video.mp4',
        name: 'Video',
        type: MediaType.video,
        size: 2,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const [],
        directoryId: 'dir',
        bookmarkData: null,
      ),
    ];
  });

  test('initializes paused state when media exist', () {
    final viewModel = SlideshowViewModel(
      media,
      tagMutationService: tagMutationService,
    );

    expect(viewModel.state, isA<SlideshowPaused>());
    expect(viewModel.currentIndex, 0);
    expect(viewModel.totalItems, media.length);
  });

  test('start, pause, and resume slideshow transitions', () {
    final viewModel = SlideshowViewModel(
      media,
      tagMutationService: tagMutationService,
    );

    viewModel.startSlideshow();
    expect(viewModel.state, isA<SlideshowPlaying>());

    viewModel.pauseSlideshow();
    expect(viewModel.state, isA<SlideshowPaused>());

    viewModel.resumeSlideshow();
    expect(viewModel.state, isA<SlideshowPlaying>());
  });

  test('advances and finishes slideshow respecting looping', () {
    fakeAsync((async) {
      final viewModel = SlideshowViewModel(
        media,
        tagMutationService: tagMutationService,
      );

      viewModel.startSlideshow();
      viewModel.toggleLoop();
      viewModel.nextItem();
      expect(viewModel.currentIndex, 1);

      viewModel.toggleLoop();
      viewModel.nextItem();
      expect(viewModel.state, isA<SlideshowFinished>());

      async.flushTimers();
    });
  });

  test('updateProgress clamps values and keeps state consistent', () {
    final viewModel = SlideshowViewModel(
      media,
      tagMutationService: tagMutationService,
    );

    viewModel.startSlideshow();
    viewModel.updateProgress(1.5);

    final state = viewModel.state as SlideshowPlaying;
    expect(state.progress, 1.0);
  });

  test('toggleTag updates media and emits state change', () async {
    final tag = TagEntity(id: 't1', name: 'Tag');
    final updatedMedia = media.first.copyWith(tagIds: const ['t1']);
    when(tagMutationService.toggleTagForMedia(media.first, tag)).thenAnswer(
      (_) async => TagMutationResult(
        outcome: TagMutationOutcome.added,
        updatedMedia: updatedMedia,
      ),
    );

    final viewModel = SlideshowViewModel(
      media,
      tagMutationService: tagMutationService,
    );

    final result = await viewModel.toggleTag(tag);

    expect(result.outcome, TagMutationOutcome.added);
    expect(viewModel.currentMedia?.tagIds, contains(tag.id));
  });
}
