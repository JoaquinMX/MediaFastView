import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_error.dart';
import '../../domain/entities/favorite_item_type.dart';
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
      final favorites = <FavoriteModel>[];
      var requiresMigration = false;

      for (final entry in jsonList) {
        final result = _deserializeFavorite(entry);
        if (result == null) {
          requiresMigration = true;
          continue;
        }
        favorites.add(result.model);
        requiresMigration = requiresMigration || result.migrated;
      }

      if (requiresMigration) {
        await saveFavorites(favorites);
      }

      return favorites;
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
    await addFavorites([favorite]);
  }

  /// Removes a favorite by media ID.
  Future<void> removeFavorite(String itemId) async {
    await removeFavorites([itemId]);
  }

  /// Adds multiple favorites in a single persistence operation.
  Future<void> addFavorites(List<FavoriteModel> favoritesToAdd) async {
    if (favoritesToAdd.isEmpty) {
      return;
    }

    final favorites = await getFavorites();
    final keyed = <String, FavoriteModel>{
      for (final favorite in favorites)
        _favoriteKey(favorite.itemId, favorite.itemType): favorite,
    };

    for (final favorite in favoritesToAdd) {
      keyed[_favoriteKey(favorite.itemId, favorite.itemType)] = favorite;
    }

    await saveFavorites(keyed.values.toList(growable: false));
  }

  /// Removes multiple favorites by their identifiers.
  Future<void> removeFavorites(List<String> itemIds) async {
    if (itemIds.isEmpty) {
      return;
    }

    final favorites = await getFavorites();
    final ids = itemIds.toSet();
    favorites.removeWhere((fav) => ids.contains(fav.itemId));
    await saveFavorites(favorites);
  }

  /// Checks if a media item is favorited.
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType? type,
  }) async {
    final favorites = await getFavorites();
    return favorites.any(
      (fav) =>
          fav.itemId == itemId && (type == null || fav.itemType == type),
    );
  }

  /// Gets all favorite media IDs.
  Future<List<String>> getFavoriteMediaIds() async {
    final favorites = await getFavorites();
    return favorites
        .where((fav) => fav.itemType == FavoriteItemType.media)
        .map((fav) => fav.itemId)
        .toList(growable: false);
  }

  _FavoriteDeserializationResult? _deserializeFavorite(dynamic entry) {
    try {
      if (entry is Map<String, dynamic>) {
        if (entry.containsKey('itemId') && entry.containsKey('itemType')) {
          return _FavoriteDeserializationResult(
            FavoriteModel.fromJson(entry),
            migrated: false,
          );
        }

        if (entry.containsKey('mediaId')) {
          final mediaId = entry['mediaId'] as String?;
          if (mediaId == null) {
            return null;
          }

          final addedAt = _parseDate(entry['addedAt']);
          return _FavoriteDeserializationResult(
            FavoriteModel(
              itemId: mediaId,
              itemType: FavoriteItemType.media,
              addedAt: addedAt,
            ),
            migrated: true,
          );
        }
      } else if (entry is String) {
        return _FavoriteDeserializationResult(
          FavoriteModel(
            itemId: entry,
            itemType: FavoriteItemType.media,
            addedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          migrated: true,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  String _favoriteKey(String id, FavoriteItemType type) => '${type.name}::$id';
}

class _FavoriteDeserializationResult {
  const _FavoriteDeserializationResult(this.model, {required this.migrated});

  final FavoriteModel model;
  final bool migrated;
}
