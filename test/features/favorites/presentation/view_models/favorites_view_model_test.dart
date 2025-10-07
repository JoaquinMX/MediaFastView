import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
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

        await viewModel.loadFavorites();

        expect(viewModel.state, isA<FavoritesLoaded>());
        final loaded = viewModel.state as FavoritesLoaded;
        expect(loaded.favorites, [mediaId]);
        expect(loaded.media.single.id, mediaId);
      },
    );
  });

  group('toggleFavorite', () {
    test('adds favorite when not already favorited', () async {
      when(
        favoritesRepository.isFavorite(mediaId),
      ).thenAnswer((_) async => false);
      when(favoritesRepository.addFavorite(mediaId)).thenAnswer((_) async {});
      when(mediaDataSource.upsertMedia(any)).thenAnswer((_) async {});
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => [mediaId]);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);

      await viewModel.toggleFavorite(mediaEntity);

      expect(viewModel.state, isA<FavoritesLoaded>());
      final loaded = viewModel.state as FavoritesLoaded;
      expect(loaded.favorites, [mediaId]);
      verify(favoritesRepository.addFavorite(mediaId)).called(1);
      verify(mediaDataSource.upsertMedia(any)).called(1);
    });

    test('removes favorite when already favorited', () async {
      when(
        favoritesRepository.isFavorite(mediaId),
      ).thenAnswer((_) async => true);
      when(
        favoritesRepository.removeFavorite(mediaId),
      ).thenAnswer((_) async {});
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => []);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);

      await viewModel.toggleFavorite(mediaEntity);

      expect(viewModel.state, isA<FavoritesEmpty>());
      verify(favoritesRepository.removeFavorite(mediaId)).called(1);
    });
  });

  group('isFavoriteInState', () {
    test('returns true when media id is in loaded state', () async {
      when(
        favoritesRepository.getFavoriteMediaIds(),
      ).thenAnswer((_) async => [mediaId]);
      when(mediaDataSource.getMedia()).thenAnswer((_) async => [mediaModel]);

      await viewModel.loadFavorites();

      expect(viewModel.isFavoriteInState(mediaId), isTrue);
    });

    test('returns false when favorites not loaded', () {
      expect(viewModel.isFavoriteInState(mediaId), isFalse);
    });
  });
}
