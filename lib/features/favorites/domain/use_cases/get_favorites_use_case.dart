import '../repositories/favorites_repository.dart';

/// Use case for getting all favorite media IDs.
class GetFavoritesUseCase {
  const GetFavoritesUseCase(this._favoritesRepository);

  final FavoritesRepository _favoritesRepository;

  /// Executes the use case to get all favorite media IDs.
  Future<List<String>> execute() async {
    return _favoritesRepository.getFavoriteMediaIds();
  }
}
