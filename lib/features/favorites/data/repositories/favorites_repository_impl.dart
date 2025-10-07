import '../../domain/repositories/favorites_repository.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../models/favorite_model.dart';

/// Implementation of FavoritesRepository using SharedPreferences.
class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl(this._favoritesDataSource);

  final SharedPreferencesFavoritesDataSource _favoritesDataSource;

  @override
  Future<List<String>> getFavoriteMediaIds() async {
    return _favoritesDataSource.getFavoriteMediaIds();
  }

  @override
  Future<void> addFavorite(String mediaId) async {
    final favorite = FavoriteModel(mediaId: mediaId, addedAt: DateTime.now());
    await _favoritesDataSource.addFavorite(favorite);
  }

  @override
  Future<void> removeFavorite(String mediaId) async {
    await _favoritesDataSource.removeFavorite(mediaId);
  }

  @override
  Future<bool> isFavorite(String mediaId) async {
    return _favoritesDataSource.isFavorite(mediaId);
  }
}
