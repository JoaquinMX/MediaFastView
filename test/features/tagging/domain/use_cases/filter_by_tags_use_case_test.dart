import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/filter_by_tags_use_case.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockDirectoryRepository extends Mock implements DirectoryRepository {}

void main() {
  late _MockMediaRepository mediaRepository;
  late FilterByTagsUseCase useCase;
  late _MockDirectoryRepository directoryRepository;
  const tagId = 'tag-1';
  final directory = DirectoryEntity(
    id: 'dir-1',
    path: '/tmp/dir',
    name: 'Directory',
    thumbnailPath: null,
    tagIds: const [tagId],
    lastModified: DateTime(2024, 1, 1),
    bookmarkData: 'bookmark',
  );
  final cachedMedia = [
    MediaEntity(
      id: 'media-1',
      path: '/tmp/dir/media1.jpg',
      name: 'media1.jpg',
      type: MediaType.image,
      size: 100,
      lastModified: DateTime(2024, 1, 1),
      tagIds: const [tagId],
      directoryId: directory.id,
      bookmarkData: null,
    ),
    MediaEntity(
      id: 'media-2',
      path: '/tmp/dir/media2.jpg',
      name: 'media2.jpg',
      type: MediaType.image,
      size: 100,
      lastModified: DateTime(2024, 1, 2),
      tagIds: const ['other'],
      directoryId: directory.id,
      bookmarkData: null,
    ),
  ];

  setUp(() {
    directoryRepository = _MockDirectoryRepository();
    mediaRepository = _MockMediaRepository();
    useCase = FilterByTagsUseCase(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
    );
  });

  test('returns all directories when no tags are provided', () async {
    when(directoryRepository.getDirectories()).thenAnswer((_) async => [directory]);

    final result = await useCase.filterDirectories(const []);

    expect(result, [directory]);
    verify(directoryRepository.getDirectories()).called(1);
    verifyNever(directoryRepository.filterDirectoriesByTags(any));
  });

  test('filters directories when tags are provided', () async {
    when(directoryRepository.filterDirectoriesByTags(any))
        .thenAnswer((_) async => [directory]);

    final result = await useCase.filterDirectories(const ['tag-1']);

    expect(result, [directory]);
    verify(directoryRepository.filterDirectoriesByTags(const ['tag-1'])).called(1);
    verifyNever(directoryRepository.getDirectories());
  });

  test('returns empty list for media when no tags are selected', () async {
    final result = await useCase.filterMedia(const []);

    expect(result, isEmpty);
    verifyNever(mediaRepository.filterMediaByTags(any));
  });

  test('delegates media filtering when tags are provided', () async {
    when(mediaRepository.filterMediaByTags(any))
        .thenAnswer((_) async => [cachedMedia.first]);

    final result = await useCase.filterMedia(const ['tag-1']);

    expect(result, [cachedMedia.first]);
    verify(mediaRepository.filterMediaByTags(const ['tag-1'])).called(1);
  });

  test('falls back to cached media when path filtering returns empty', () async {
    when(
      mediaRepository.filterMediaByTagsForDirectory(
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      ),
    ).thenAnswer((_) async => const []);
    when(mediaRepository.getMediaForDirectory(directory.id))
        .thenAnswer((_) async => cachedMedia);

    final result =
        await useCase.filterMediaInDirectory(directory, const [tagId]);

    expect(result, hasLength(1));
    expect(result.first.id, 'media-1');
    verify(mediaRepository.filterMediaByTagsForDirectory(
      const [tagId],
      directory.path,
      bookmarkData: directory.bookmarkData,
    )).called(1);
    verify(mediaRepository.getMediaForDirectory(directory.id)).called(1);
  });

  test('falls back to cached media when path filtering throws', () async {
    when(
      mediaRepository.filterMediaByTagsForDirectory(
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      ),
    ).thenThrow(Exception('failure'));
    when(mediaRepository.getMediaForDirectory(directory.id))
        .thenAnswer((_) async => cachedMedia);

    final result =
        await useCase.filterMediaInDirectory(directory, const [tagId]);

    expect(result, hasLength(1));
    expect(result.first.id, 'media-1');
    verify(mediaRepository.getMediaForDirectory(directory.id)).called(1);
  });

  test('returns remote media when available', () async {
    when(
      mediaRepository.filterMediaByTagsForDirectory(
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      ),
    ).thenAnswer((_) async => [cachedMedia.first]);

    final result =
        await useCase.filterMediaInDirectory(directory, const [tagId]);

    expect(result, equals([cachedMedia.first]));
    verify(mediaRepository.filterMediaByTagsForDirectory(
      const [tagId],
      directory.path,
      bookmarkData: directory.bookmarkData,
    )).called(1);
    verifyNever(mediaRepository.getMediaForDirectory(directory.id));
  });
}
