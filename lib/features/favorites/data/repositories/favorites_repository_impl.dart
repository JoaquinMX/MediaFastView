import '../../domain/entities/favorite_entity.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../models/favorite_model.dart';

/// Implementation of FavoritesRepository using SharedPreferences.
class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl(this._favoritesDataSource);

  final SharedPreferencesFavoritesDataSource _favoritesDataSource;

  @override
  Future<List<FavoriteEntity>> getFavorites() async {
    final favorites = await _favoritesDataSource.getFavorites();
    return favorites.map(_mapModelToEntity).toList(growable: false);
  }

  @override
  Future<List<String>> getFavoriteMediaIds() async {
    return _favoritesDataSource.getFavoriteMediaIds();
  }

  @override
  Future<void> addFavorite(String mediaId) async {
    final favorite = FavoriteEntity(
      itemId: mediaId,
      itemType: FavoriteItemType.media,
      addedAt: DateTime.now(),
    );
    await addFavorites([favorite]);
  }

  @override
  Future<void> addFavorites(List<FavoriteEntity> favorites) async {
    if (favorites.isEmpty) {
      return;
    }

    final models = favorites.map(_mapEntityToModel).toList(growable: false);
    await _favoritesDataSource.addFavorites(models);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    await removeFavorites([itemId]);
  }

  @override
  Future<void> removeFavorites(List<String> itemIds) async {
    if (itemIds.isEmpty) {
      return;
    }

    await _favoritesDataSource.removeFavorites(itemIds);
  }

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async {
    return _favoritesDataSource.isFavorite(itemId, type: type);
  }

  FavoriteModel _mapEntityToModel(FavoriteEntity entity) {
    return FavoriteModel(
      itemId: entity.itemId,
      itemType: entity.itemType,
      addedAt: entity.addedAt,
      metadata: entity.metadata == null
          ? null
          : Map<String, dynamic>.from(entity.metadata!),
    );
  }

  FavoriteEntity _mapModelToEntity(FavoriteModel model) {
    return FavoriteEntity(
      itemId: model.itemId,
      itemType: model.itemType,
      addedAt: model.addedAt,
      metadata:
          model.metadata == null ? null : Map<String, dynamic>.from(model.metadata!),
    );
  }
}
