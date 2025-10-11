import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';

import '../../../../mocks.mocks.dart';

void main() {
  late MockFavoritesRepository favoritesRepository;
  late MockSharedPreferencesMediaDataSource mediaDataSource;
  late FavoritesViewModel viewModel;

  const mediaId = 'media-1';
  final now = DateTime(2024, 1, 1);
  const directoryId = 'directory-1';
  const directoryPath = '/path/to/directory';

  final mediaModel = MediaModel(
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
    favoritesRepository = MockFavoritesRepository();
    mediaDataSource = MockSharedPreferencesMediaDataSource();
    viewModel = FavoritesViewModel(favoritesRepository, mediaDataSource);
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
      verifyZeroInteractions(mediaDataSource);
    });

    test('emits FavoritesEmpty when media cannot be resolved', () async {
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => [mediaId]);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => []);
      when(favoritesRepository.getFavorites())
          .thenAnswer((_) async => const []);

      await viewModel.loadFavorites();

      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.getFavoriteMediaIds()).called(1);
      verify(mediaDataSource.getMedia()).called(1);
    });

    test(
      'emits FavoritesLoaded with entities when media is available',
      () async {
        when(
          favoritesRepository.getFavoriteMediaIds(),
        ).thenAnswer((_) async => [mediaId]);
        when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
        when(favoritesRepository.getFavorites())
            .thenAnswer((_) async => const []);

        await viewModel.loadFavorites();

        expect(viewModel.state, isA<FavoritesLoaded>());
        final loaded = viewModel.state as FavoritesLoaded;
        expect(loaded.favorites, [mediaId]);
        expect(loaded.media.single.id, mediaId);
      },
    );
  });

  group('toggleFavoritesForMedia', () {
    test('adds favorites and persists media when not previously favorited', () async {
      when(
        favoritesRepository.isFavorite(
          mediaId,
          type: FavoriteItemType.media,
        ),
      ).thenAnswer((_) async => false);
      when(favoritesRepository.addFavorites(any)).thenAnswer((_) async {});
      when(favoritesRepository.removeFavorites(any)).thenAnswer((_) async {});
      when(mediaDataSource.upsertMedia(any)).thenAnswer((_) async {});
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => [mediaId]);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
      when(favoritesRepository.getFavorites()).thenAnswer((_) async => const []);

      final result = await viewModel.toggleFavoritesForMedia([mediaEntity]);

      expect(result.added, 1);
      expect(result.removed, 0);
      expect(viewModel.state, isA<FavoritesLoaded>());
      verify(favoritesRepository.addFavorites(any)).called(1);
      verify(mediaDataSource.upsertMedia(any)).called(1);
      verifyNever(favoritesRepository.removeFavorites(any));
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
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
      when(favoritesRepository.getFavorites()).thenAnswer((_) async => const []);

      final result = await viewModel.toggleFavoritesForMedia([mediaEntity]);

      expect(result.added, 0);
      expect(result.removed, 1);
      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.removeFavorites(any)).called(1);
      verifyNever(favoritesRepository.addFavorites(any));
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
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
      when(favoritesRepository.getFavorites()).thenAnswer((_) async => const []);

      final result =
          await viewModel.toggleFavoritesForDirectories([directoryEntity]);

      expect(result.added, 1);
      expect(result.removed, 0);
      verify(favoritesRepository.addFavorites(any)).called(1);
      verifyNever(mediaDataSource.upsertMedia(any));
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
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
      when(favoritesRepository.getFavorites()).thenAnswer((_) async => const []);

      final result =
          await viewModel.toggleFavoritesForDirectories([directoryEntity]);

      expect(result.added, 0);
      expect(result.removed, 1);
      verify(favoritesRepository.removeFavorites(any)).called(1);
      verifyNever(favoritesRepository.addFavorites(any));
    });
  });

  group('isFavoriteInState', () {
    test('returns true when media id is in loaded state', () async {
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => [mediaId]);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);
      when(favoritesRepository.getFavorites()).thenAnswer((_) async => const []);

      await viewModel.loadFavorites();

      expect(viewModel.isFavoriteInState(mediaId), isTrue);
    });

    test('returns false when favorites not loaded', () {
      expect(viewModel.isFavoriteInState(mediaId), isFalse);
    });
  });
}
