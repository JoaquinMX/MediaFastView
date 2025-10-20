import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/get_media_use_case.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late _MockMediaRepository mediaRepository;
  late GetMediaUseCase useCase;

  const directoryPath = '/path/to/directory';
  const directoryId = 'directory-id';
  const bookmark = 'bookmark-data';

  setUp(() {
    mediaRepository = _MockMediaRepository();
    useCase = GetMediaUseCase(mediaRepository);
  });

  group('forDirectoryPath', () {
    test('delegates to repository with bookmark data', () async {
      when(
        mediaRepository.getMediaForDirectoryPath(
          any,
          bookmarkData: anyNamed('bookmarkData'),
        ),
      ).thenAnswer((_) async => const <MediaEntity>[]);

      await useCase.forDirectoryPath(directoryPath, bookmarkData: bookmark);

      verify(
        mediaRepository.getMediaForDirectoryPath(
          directoryPath,
          bookmarkData: bookmark,
        ),
      ).called(1);
    });
  });

  group('forDirectoryId', () {
    test('delegates to repository', () async {
      when(mediaRepository.getMediaForDirectory(any))
          .thenAnswer((_) async => const <MediaEntity>[]);

      await useCase.forDirectoryId(directoryId);

      verify(mediaRepository.getMediaForDirectory(directoryId)).called(1);
    });
  });

  group('entireLibrary', () {
    test('delegates to filterMediaByTags with empty tags', () async {
      when(mediaRepository.filterMediaByTags(any))
          .thenAnswer((_) async => const <MediaEntity>[]);

      await useCase.entireLibrary();

      verify(mediaRepository.filterMediaByTags(const <String>[])).called(1);
    });
  });

  group('filterByTagsForDirectory', () {
    test('delegates to repository with bookmark data', () async {
      const tags = ['tag-1', 'tag-2'];
      when(
        mediaRepository.filterMediaByTagsForDirectory(
          any,
          any,
          bookmarkData: anyNamed('bookmarkData'),
        ),
      ).thenAnswer((_) async => const <MediaEntity>[]);

      await useCase.filterByTagsForDirectory(
        tags,
        directoryPath,
        bookmarkData: bookmark,
      );

      verify(
        mediaRepository.filterMediaByTagsForDirectory(
          tags,
          directoryPath,
          bookmarkData: bookmark,
        ),
      ).called(1);
    });
  });
}
