import '../entities/favorite_entity.dart';
import '../entities/favorite_item_type.dart';

/// Repository interface for favorites operations.
/// Provides methods for managing favorite items across item types.
abstract class FavoritesRepository {
  /// Retrieves every persisted favorite.
  Future<List<FavoriteEntity>> getFavorites();

  /// Retrieves all favorite media IDs.
  Future<List<String>> getFavoriteMediaIds();

  /// Retrieves all favorite directory IDs.
  Future<List<String>> getFavoriteDirectoryIds();

  /// Adds a media item to favorites.
  Future<void> addFavorite(String mediaId);

  /// Adds multiple favorites in a single batch.
  Future<void> addFavorites(List<FavoriteEntity> favorites);

  /// Removes a media item from favorites.
  Future<void> removeFavorite(String itemId);

  /// Removes multiple favorites by their identifiers.
  Future<void> removeFavorites(List<String> itemIds);

  /// Checks if an item is favorited.
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  });
}
