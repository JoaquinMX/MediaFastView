import 'package:fake_async/fake_async.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/slideshow_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/settings/domain/entities/playback_settings.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/shared/utils/tag_mutation_service.dart';

import 'slideshow_view_model_test.mocks.dart';

@GenerateMocks([TagMutationService])

void main() {
  late MockTagMutationService tagMutationService;
  late List<MediaEntity> media;

  setUp(() {
    tagMutationService = MockTagMutationService();
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

  group('SlideshowViewModel', () {
    test('initializes paused state when media exist', () {
      final viewModel = SlideshowViewModel(
        media,
        tagMutationService: tagMutationService,
        playbackSettings: const PlaybackSettings.initial(),
      );

      expect(viewModel.state, isA<SlideshowPaused>());
      expect(viewModel.currentIndex, equals(0));
      expect(viewModel.totalItems, equals(media.length));
    });

    test('start, pause, and resume slideshow transitions', () {
      final viewModel = SlideshowViewModel(
        media,
        tagMutationService: tagMutationService,
        playbackSettings: const PlaybackSettings.initial(),
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
          playbackSettings: const PlaybackSettings.initial(),
        );

        viewModel.startSlideshow();
        viewModel.toggleLoop();
        viewModel.nextItem();
        expect(viewModel.currentIndex, equals(1));

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
        playbackSettings: const PlaybackSettings.initial(),
      );

      viewModel.startSlideshow();
      viewModel.updateProgress(1.5);

      final state = viewModel.state as SlideshowPlaying;
      expect(state.progress, equals(1.5));
    });

    test('toggleTag updates media and emits state change', () async {
      final tag = TagEntity(id: 't1', name: 'Tag', color: 0xFF000000, createdAt: DateTime(2024, 1, 1));
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
        playbackSettings: const PlaybackSettings.initial(),
      );

      final result = await viewModel.toggleTag(tag);

      expect(result.outcome, equals(TagMutationOutcome.added));
      expect(viewModel.currentMedia?.tagIds, contains(tag.id));
    });
  });
}
