import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_error.dart';
import '../models/favorite_model.dart';

/// Data source for favorites operations using SharedPreferences.
class SharedPreferencesFavoritesDataSource {
  const SharedPreferencesFavoritesDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const String _favoritesKey = 'favorites';

  /// Retrieves all favorites from storage.
  Future<List<FavoriteModel>> getFavorites() async {
    try {
      final jsonString = _prefs.getString(_favoritesKey);
      if (jsonString == null) return [];

      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => FavoriteModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw PersistenceError('Failed to load favorites: $e');
    }
  }

  /// Saves all favorites to storage.
  Future<void> saveFavorites(List<FavoriteModel> favorites) async {
    try {
      final jsonList = favorites.map((fav) => fav.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs.setString(_favoritesKey, jsonString);
    } catch (e) {
      throw PersistenceError('Failed to save favorites: $e');
    }
  }

  /// Adds a favorite.
  Future<void> addFavorite(FavoriteModel favorite) async {
    final favorites = await getFavorites();
    // Remove if already exists to avoid duplicates
    favorites.removeWhere((fav) => fav.mediaId == favorite.mediaId);
    favorites.add(favorite);
    await saveFavorites(favorites);
  }

  /// Removes a favorite by media ID.
  Future<void> removeFavorite(String mediaId) async {
    final favorites = await getFavorites();
    favorites.removeWhere((fav) => fav.mediaId == mediaId);
    await saveFavorites(favorites);
  }

  /// Checks if a media item is favorited.
  Future<bool> isFavorite(String mediaId) async {
    final favorites = await getFavorites();
    return favorites.any((fav) => fav.mediaId == mediaId);
  }

  /// Gets all favorite media IDs.
  Future<List<String>> getFavoriteMediaIds() async {
    final favorites = await getFavorites();
    return favorites.map((fav) => fav.mediaId).toList();
  }
}
