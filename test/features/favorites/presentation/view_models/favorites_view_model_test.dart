import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/favorite_media_use_case.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockFavoriteMediaUseCase extends Mock implements FavoriteMediaUseCase {}

void main() {
  late _MockFavoritesRepository favoritesRepository;
  late _MockFavoriteMediaUseCase favoriteMediaUseCase;
  late FavoritesViewModel viewModel;

  const mediaId = 'media-1';
  final now = DateTime(2024, 1, 1);
  const directoryId = 'directory-1';
  const directoryPath = '/path/to/directory';

  final mediaEntity = MediaEntity(
    id: mediaId,
    path: '/path/to/media.jpg',
    name: 'media.jpg',
    type: MediaType.image,
    size: 1024,
    lastModified: now,
    tagIds: const [],
    directoryId: directoryId,
    bookmarkData: null,
  );

  final directoryEntity = DirectoryEntity(
    id: directoryId,
    path: directoryPath,
    name: 'Sample Directory',
    thumbnailPath: null,
    tagIds: const [],
    lastModified: now,
    bookmarkData: null,
  );

  setUp(() {
    favoritesRepository = _MockFavoritesRepository();
    favoriteMediaUseCase = _MockFavoriteMediaUseCase();
    viewModel = FavoritesViewModel(
      favoritesRepository,
      favoriteMediaUseCase,
    );

    when(favoritesRepository.getFavoriteDirectoryIds())
        .thenAnswer((_) async => <String>[]);
  });

  group('loadFavorites', () {
    test('emits FavoritesEmpty when no favorites are stored', () async {
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => []);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);

      await viewModel.loadFavorites();

      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.getFavoriteMediaIds()).called(1);
      verifyZeroInteractions(favoriteMediaUseCase);
    });

    test('emits FavoritesEmpty when media cannot be resolved', () async {
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => [mediaId]);
      when(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
          .thenAnswer((_) async => const []);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);

      await viewModel.loadFavorites();

      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.getFavoriteMediaIds()).called(1);
      verify(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
          .called(1);
    });

    test(
      'emits FavoritesLoaded with entities when media is available',
      () async {
        when(
          favoritesRepository.getFavoriteMediaIds(),
        ).thenAnswer((_) async => [mediaId]);
        when(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
            .thenAnswer((_) async => [mediaEntity]);
        when(favoritesRepository.getFavorites())
            .thenAnswer((_) async => const []);

        await viewModel.loadFavorites();

        expect(viewModel.state, isA<FavoritesLoaded>());
        final loaded = viewModel.state as FavoritesLoaded;
        expect(loaded.favorites, [mediaId]);
        expect(loaded.media.single.id, mediaId);
        verify(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
            .called(1);
      },
    );
  });

  group('toggleFavoritesForMedia', () {
    test('adds favorites and persists media when not previously favorited',
        () async {
      when(
        favoritesRepository.isFavorite(
          mediaId,
          type: FavoriteItemType.media,
        ),
      ).thenAnswer((_) async => false);
      when(favoritesRepository.addFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.removeFavorites(any)).thenAnswer((_) async {});
      when(favoriteMediaUseCase.persistMedia(any)).thenAnswer((_) async {});
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => [mediaId]);
      when(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
          .thenAnswer((_) async => [mediaEntity]);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);

      final result = await viewModel.toggleFavoritesForMedia([mediaEntity]);

      expect(result.added, 1);
      expect(result.removed, 0);
      expect(viewModel.state, isA<FavoritesLoaded>());
      verify(favoritesRepository.addFavorites(any)).called(1);
      verify(favoriteMediaUseCase.persistMedia(mediaEntity)).called(1);
      verifyNever(favoritesRepository.removeFavorites(any));
      verify(favoriteMediaUseCase.resolveMediaForFavorites([mediaId]))
          .called(1);
    });

    test('removes favorites when already favorited', () async {
      when(
        favoritesRepository.isFavorite(
          mediaId,
          type: FavoriteItemType.media,
        ),
      ).thenAnswer((_) async => true);
      when(favoritesRepository.addFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.removeFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => <String>[]);
      when(favoriteMediaUseCase.resolveMediaForFavorites(const []))
          .thenAnswer((_) async => const []);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);

      final result = await viewModel.toggleFavoritesForMedia([mediaEntity]);

      expect(result.added, 0);
      expect(result.removed, 1);
      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.removeFavorites(any)).called(1);
      verifyNever(favoritesRepository.addFavorites(any));
      verify(favoriteMediaUseCase.resolveMediaForFavorites(const [])).called(1);
    });
  });

  group('toggleFavoritesForDirectories', () {
    test('adds directories when not favorited', () async {
      when(
        favoritesRepository.isFavorite(
          directoryId,
          type: FavoriteItemType.directory,
        ),
      ).thenAnswer((_) async => false);
      when(favoritesRepository.addFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.removeFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => <String>[]);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);
      when(favoriteMediaUseCase.resolveMediaForFavorites(const []))
          .thenAnswer((_) async => const []);

      final result =
          await viewModel.toggleFavoritesForDirectories([directoryEntity]);

      expect(result.added, 1);
      expect(result.removed, 0);
      verify(favoritesRepository.addFavorites(any)).called(1);
      verifyNever(favoriteMediaUseCase.persistMedia(any));
    });

    test('removes directories when already favorited', () async {
      when(
        favoritesRepository.isFavorite(
          directoryId,
          type: FavoriteItemType.directory,
        ),
      ).thenAnswer((_) async => true);
      when(favoritesRepository.addFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.removeFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => <String>[]);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);
      when(favoriteMediaUseCase.resolveMediaForFavorites(const []))
          .thenAnswer((_) async => const []);

      final result =
          await viewModel.toggleFavoritesForDirectories([directoryEntity]);

      expect(result.added, 0);
      expect(result.removed, 1);
      verify(favoritesRepository.removeFavorites(any)).called(1);
      verifyNever(favoritesRepository.addFavorites(any));
    });
  });
}
