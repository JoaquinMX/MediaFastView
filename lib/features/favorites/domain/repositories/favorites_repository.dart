/// Repository interface for favorites operations.
/// Provides methods for managing favorite media items.
abstract class FavoritesRepository {
  /// Retrieves all favorite media IDs.
  Future<List<String>> getFavoriteMediaIds();

  /// Adds a media item to favorites.
  Future<void> addFavorite(String mediaId);

  /// Removes a media item from favorites.
  Future<void> removeFavorite(String mediaId);

  /// Checks if a media item is favorited.
  Future<bool> isFavorite(String mediaId);
}
