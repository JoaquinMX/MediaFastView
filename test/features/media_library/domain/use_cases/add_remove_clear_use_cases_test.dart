import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/add_directory_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/clear_media_cache_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/remove_directory_use_case.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';

import 'add_remove_clear_use_cases_test.mocks.dart';

@GenerateMocks([DirectoryRepository, MediaRepository, FavoritesRepository])
void _dummy() {}

void main() {
  group('AddDirectoryUseCase', () {
    late MockDirectoryRepository directoryRepository;
    late AddDirectoryUseCase useCase;

    setUp(() {
      directoryRepository = MockDirectoryRepository();
      useCase = AddDirectoryUseCase(directoryRepository);
    });

    test('creates directory entity from path and delegates to repository', () async {
      const path = '/home/user/Videos';
      final expectedId = generateDirectoryId(path);

      when(directoryRepository.addDirectory(any, silent: anyNamed('silent')))
          .thenAnswer((_) async {});

      await useCase(path, silent: true);

      final capturedEntity =
          verify(directoryRepository.addDirectory(captureAny, silent: true))
              .captured
              .single as DirectoryEntity;

      expect(capturedEntity.id, expectedId);
      expect(capturedEntity.path, path);
      expect(capturedEntity.name, 'Videos');
      expect(capturedEntity.tagIds, isEmpty);
      expect(capturedEntity.thumbnailPath, isNull);
    });
  });

  group('RemoveDirectoryUseCase', () {
    late MockDirectoryRepository directoryRepository;
    late MockMediaRepository mediaRepository;
    late MockFavoritesRepository favoritesRepository;
    late RemoveDirectoryUseCase useCase;

    const directoryId = 'dir-1';
    const directoryPath = '/library/dir-1';

    setUp(() {
      directoryRepository = MockDirectoryRepository();
      mediaRepository = MockMediaRepository();
      favoritesRepository = MockFavoritesRepository();
      useCase = RemoveDirectoryUseCase(
        directoryRepository,
        mediaRepository,
        favoritesRepository,
      );
    });

    test('removes directory and cascades favorite/tag cleanup', () async {
      final media = [
        MediaEntity(
          id: 'media-1',
          directoryId: directoryId,
          path: '/file-1.jpg',
          name: 'file-1.jpg',
          type: MediaType.image,
          size: 1024,
          tagIds: ['tag-1'],
          lastModified: DateTime(2024, 1, 1),
        ),
        MediaEntity(
          id: 'media-2',
          directoryId: directoryId,
          path: '/file-2.jpg',
          name: 'file-2.jpg',
          type: MediaType.image,
          size: 2048,
          tagIds: [],
          lastModified: DateTime(2024, 1, 1),
        ),
      ];

      when(directoryRepository.getDirectoryById(directoryId)).thenAnswer(
        (_) async => DirectoryEntity(
          id: directoryId,
          path: directoryPath,
          name: 'dir-1',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: 'bookmark',
        ),
      );
      when(
        mediaRepository.getMediaForDirectoryPath(
          any,
          bookmarkData: anyNamed('bookmarkData'),
        ),
      ).thenAnswer((_) async => media.cast<MediaEntity>());
      when(favoritesRepository.isFavorite(any)).thenAnswer((_) async => true);
      when(favoritesRepository.removeFavorite(any)).thenAnswer((_) async {});
      when(mediaRepository.updateMediaTags(any, any))
          .thenAnswer((_) async {});
      when(directoryRepository.removeDirectory(directoryId))
          .thenAnswer((_) async {});
      when(mediaRepository.removeMediaForDirectory(directoryId))
          .thenAnswer((_) async {});

      await useCase(directoryId);

      verify(directoryRepository.getDirectoryById(directoryId)).called(1);
      verify(
        mediaRepository.getMediaForDirectoryPath(
          directoryPath,
          bookmarkData: 'bookmark',
        ),
      ).called(1);
      verify(favoritesRepository.removeFavorite('media-1')).called(1);
      verify(mediaRepository.updateMediaTags('media-1', [])).called(1);
      verify(favoritesRepository.removeFavorite('media-2')).called(1);
      verifyNever(mediaRepository.updateMediaTags('media-2', any));
      verify(directoryRepository.removeDirectory(directoryId)).called(1);
      verify(mediaRepository.removeMediaForDirectory(directoryId)).called(1);
    });

    test('returns early when directory is missing', () async {
      when(directoryRepository.getDirectoryById(directoryId))
          .thenAnswer((_) async => null);

      await useCase(directoryId);

      verify(directoryRepository.getDirectoryById(directoryId)).called(1);
      verifyNever(directoryRepository.removeDirectory(any));
      verifyNever(mediaRepository.removeMediaForDirectory(any));
    });
  });

  group('ClearMediaCacheUseCase', () {
    late MockMediaRepository mediaRepository;
    late ClearMediaCacheUseCase useCase;

    setUp(() {
      mediaRepository = MockMediaRepository();
      useCase = ClearMediaCacheUseCase(mediaRepository);
    });

    test('prunes only entries confirmed missing from disk', () async {
      when(mediaRepository.pruneMissingMedia()).thenAnswer((_) async => 3);

      final removed = await useCase();

      expect(removed, 3);
      verify(mediaRepository.pruneMissingMedia()).called(1);
    });

    test('never falls back to the destructive directoryId-based prune',
        () async {
      when(mediaRepository.pruneMissingMedia()).thenAnswer((_) async => 0);

      await useCase();

      // Pruning by directoryId deleted every media item living in a subfolder
      // — its directoryId is the subfolder's, not the library root's — and took
      // that media's tag assignments with it. It must never be used here again.
      verifyNever(mediaRepository.removeMediaNotInDirectories(any));
      verifyNever(mediaRepository.clearAllMedia());
    });
  });
}
