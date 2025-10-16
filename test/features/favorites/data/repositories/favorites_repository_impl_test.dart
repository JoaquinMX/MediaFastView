import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

class _MockIsarFavoritesDataSource extends Mock implements IsarFavoritesDataSource {}

void main() {
  group('FavoritesRepositoryImpl', () {
    late FavoritesRepositoryImpl repository;
    late _MockIsarFavoritesDataSource isarFavoritesDataSource;
    late MockSharedPreferencesFavoritesDataSource legacyFavoritesDataSource;

    setUp(() {
      isarFavoritesDataSource = _MockIsarFavoritesDataSource();
      legacyFavoritesDataSource = MockSharedPreferencesFavoritesDataSource();

      repository = FavoritesRepositoryImpl(
        isarFavoritesDataSource,
        legacyFavoritesDataSource,
      );
    });

    test('getFavorites falls back to legacy storage and seeds Isar', () async {
      final favoriteModel = FavoriteModel(
        itemId: 'media-1',
        itemType: FavoriteItemType.media,
        addedAt: DateTime(2024, 1, 1),
      );

      when(isarFavoritesDataSource.getFavorites()).thenAnswer((_) async => <FavoriteModel>[]);
      when(legacyFavoritesDataSource.getFavorites()).thenAnswer((_) async => <FavoriteModel>[favoriteModel]);
      when(isarFavoritesDataSource.saveFavorites(any)).thenAnswer((_) async {});

      final favorites = await repository.getFavorites();

      expect(favorites, equals(<FavoriteEntity>[
        FavoriteEntity(
          itemId: favoriteModel.itemId,
          itemType: favoriteModel.itemType,
          addedAt: favoriteModel.addedAt,
        ),
      ]));
      verify(isarFavoritesDataSource.saveFavorites(<FavoriteModel>[favoriteModel])).called(1);
    });

    test('addFavorites writes to both data sources', () async {
      final favorite = FavoriteEntity(
        itemId: 'media-2',
        itemType: FavoriteItemType.media,
        addedAt: DateTime(2024, 2, 1),
        metadata: const {'foo': 'bar'},
      );

      when(isarFavoritesDataSource.addFavorites(any)).thenAnswer((_) async {});
      when(legacyFavoritesDataSource.addFavorites(any)).thenAnswer((_) async {});

      await repository.addFavorites(<FavoriteEntity>[favorite]);

      final expectedModel = FavoriteModel(
        itemId: favorite.itemId,
        itemType: favorite.itemType,
        addedAt: favorite.addedAt,
        metadata: favorite.metadata,
      );
      verify(isarFavoritesDataSource.addFavorites(<FavoriteModel>[expectedModel])).called(1);
      verify(legacyFavoritesDataSource.addFavorites(<FavoriteModel>[expectedModel])).called(1);
    });
  });
}
