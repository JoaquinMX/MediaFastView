import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

void main() {
  group('FavoritesRepositoryImpl', () {
    late FavoritesRepositoryImpl repository;
    late MockIsarFavoritesDataSource isarFavoritesDataSource;

    setUp(() {
      isarFavoritesDataSource = MockIsarFavoritesDataSource();
      repository = FavoritesRepositoryImpl(isarFavoritesDataSource);
    });

    test('getFavorites returns persisted favorites', () async {
      final favoriteModel = FavoriteModel(
        itemId: 'media-1',
        itemType: FavoriteItemType.media,
        addedAt: DateTime(2024, 1, 1),
      );

      when(isarFavoritesDataSource.getFavorites()).thenAnswer((_) async => <FavoriteModel>[favoriteModel]);

      final favorites = await repository.getFavorites();

      expect(favorites, equals(<FavoriteEntity>[
        FavoriteEntity(
          itemId: favoriteModel.itemId,
          itemType: favoriteModel.itemType,
          addedAt: favoriteModel.addedAt,
        ),
      ]));
      verify(isarFavoritesDataSource.getFavorites()).called(1);
    });

    test('addFavorites writes to Isar', () async {
      final favorite = FavoriteEntity(
        itemId: 'media-2',
        itemType: FavoriteItemType.media,
        addedAt: DateTime(2024, 2, 1),
        metadata: const {'foo': 'bar'},
      );

      when(isarFavoritesDataSource.addFavorites(any)).thenAnswer((_) async {});

      await repository.addFavorites(<FavoriteEntity>[favorite]);

      final expectedModel = FavoriteModel(
        itemId: favorite.itemId,
        itemType: favorite.itemType,
        addedAt: favorite.addedAt,
        metadata: favorite.metadata,
      );
      verify(isarFavoritesDataSource.addFavorites(<FavoriteModel>[expectedModel])).called(1);
    });
  });
}
