import '../repositories/favorites_repository.dart';

/// Use case for toggling favorite status of a media item.
class ToggleFavoriteUseCase {
  const ToggleFavoriteUseCase(this._favoritesRepository);

  final FavoritesRepository _favoritesRepository;

  /// Executes the use case to toggle favorite status for a media item.
  Future<void> execute(String mediaId) async {
    final isCurrentlyFavorite = await _favoritesRepository.isFavorite(mediaId);

    if (isCurrentlyFavorite) {
      await _favoritesRepository.removeFavorite(mediaId);
    } else {
      await _favoritesRepository.addFavorite(mediaId);
    }
  }
}
