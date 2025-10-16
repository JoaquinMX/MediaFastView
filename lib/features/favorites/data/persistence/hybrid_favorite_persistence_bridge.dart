import '../../domain/entities/favorite_item_type.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../isar/isar_favorites_data_source.dart';
import '../models/favorite_model.dart';

/// Bridge that mirrors favorite persistence operations between Isar and the
/// legacy SharedPreferences implementation.
class FavoritePersistenceBridge {
  const FavoritePersistenceBridge({
    required IsarFavoritesDataSource isarFavoritesDataSource,
    required SharedPreferencesFavoritesDataSource legacyFavoritesDataSource,
  })  : _isarFavoritesDataSource = isarFavoritesDataSource,
        _legacyFavoritesDataSource = legacyFavoritesDataSource;

  final IsarFavoritesDataSource _isarFavoritesDataSource;
  final SharedPreferencesFavoritesDataSource _legacyFavoritesDataSource;

  Future<List<FavoriteModel>> loadFavorites() async {
    final isarFavorites = await _isarFavoritesDataSource.getFavorites();
    if (isarFavorites.isNotEmpty) {
      return isarFavorites;
    }

    final legacyFavorites = await _legacyFavoritesDataSource.getFavorites();
    if (legacyFavorites.isNotEmpty) {
      await _isarFavoritesDataSource.saveFavorites(legacyFavorites);
    }
    return legacyFavorites;
  }

  Future<void> addFavorite(FavoriteModel favorite) async {
    await _isarFavoritesDataSource.addFavorite(favorite);
    await _legacyFavoritesDataSource.addFavorite(favorite);
  }

  Future<void> addFavorites(List<FavoriteModel> favorites) async {
    if (favorites.isEmpty) {
      return;
    }
    await _isarFavoritesDataSource.addFavorites(favorites);
    await _legacyFavoritesDataSource.addFavorites(favorites);
  }

  Future<void> removeFavorites(List<String> itemIds) async {
    if (itemIds.isEmpty) {
      return;
    }
    await _isarFavoritesDataSource.removeFavorites(itemIds);
    await _legacyFavoritesDataSource.removeFavorites(itemIds);
  }

  Future<void> removeFavorite(String itemId) async {
    await _isarFavoritesDataSource.removeFavorite(itemId);
    await _legacyFavoritesDataSource.removeFavorite(itemId);
  }

  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType? type,
  }) async {
    if (await _isarFavoritesDataSource.isFavorite(itemId, type: type)) {
      return true;
    }
    return _legacyFavoritesDataSource.isFavorite(itemId, type: type);
  }

  Future<List<String>> getFavoriteMediaIds() async {
    final favorites = await loadFavorites();
    return favorites
        .where((favorite) => favorite.itemType == FavoriteItemType.media)
        .map((favorite) => favorite.itemId)
        .toList(growable: false);
  }
}

