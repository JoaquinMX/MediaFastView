import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/isar_directory_data_source.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../models/favorite_model.dart';
import 'favorite_collection.dart';

/// Signature for constructing a [FavoriteCollectionStore] bound to Isar.
typedef FavoriteCollectionStoreBuilder = FavoriteCollectionStore Function(
  IsarDatabase database,
);

/// Data source that persists favorites using Isar collections.
class IsarFavoritesDataSource {
  IsarFavoritesDataSource(
    this._database, {
    FavoriteCollectionStoreBuilder? favoriteStoreBuilder,
    MediaCollectionStoreBuilder? mediaStoreBuilder,
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
  })  : _favoriteStoreBuilder =
            favoriteStoreBuilder ?? _defaultFavoriteStoreBuilder,
        _mediaStoreBuilder = mediaStoreBuilder ?? _defaultMediaStoreBuilder,
        _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder;

  final IsarDatabase _database;
  final FavoriteCollectionStoreBuilder _favoriteStoreBuilder;
  final MediaCollectionStoreBuilder _mediaStoreBuilder;
  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;

  late final FavoriteCollectionStore _favoriteStore =
      _favoriteStoreBuilder(_database);
  late final MediaCollectionStore _mediaStore = _mediaStoreBuilder(_database);
  late final DirectoryCollectionStore _directoryStore =
      _directoryStoreBuilder(_database);

  /// Retrieves all persisted favorites sorted by creation time.
  Future<List<FavoriteModel>> getFavorites() async {
    await _ensureReady();
    try {
      final collections = await _favoriteStore.getAll();
      collections.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load favorites: $error'),
        stackTrace,
      );
    }
  }

  /// Persists [favorites] replacing existing records.
  Future<void> saveFavorites(List<FavoriteModel> favorites) async {
    final collections = await _mapModels(favorites);
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        await _favoriteStore.clear();
        if (collections.isNotEmpty) {
          await _favoriteStore.putAll(collections);
        }
      });
    }, 'Failed to save favorites');
  }

  /// Adds a new [favorite] entry.
  Future<void> addFavorite(FavoriteModel favorite) {
    return addFavorites(<FavoriteModel>[favorite]);
  }

  /// Adds multiple [favorites] ensuring existing entries are replaced.
  Future<void> addFavorites(List<FavoriteModel> favorites) async {
    if (favorites.isEmpty) {
      return;
    }

    final collections = await _mapModels(favorites);
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        for (final collection in collections) {
          await _favoriteStore.put(collection);
        }
      });
    }, 'Failed to add favorites');
  }

  /// Removes the favorite identified by [itemId].
  Future<void> removeFavorite(
    String itemId, {
    FavoriteItemType? type,
  }) async {
    await removeFavorites(<String>[itemId], type: type);
  }

  /// Removes favorites for the provided [itemIds].
  Future<void> removeFavorites(
    List<String> itemIds, {
    FavoriteItemType? type,
  }) async {
    if (itemIds.isEmpty) {
      return;
    }

    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        if (type != null) {
          final ids = itemIds
              .map((itemId) {
                final key = _favoriteKey(itemId, type);
                final hash = sha256.convert(utf8.encode(key)).bytes;
                return hash.fold<int>(0, (prev, element) => prev + element);
              })
              .toList(growable: false);
          await _favoriteStore.deleteByIds(ids);
          return;
        }

        final toDelete = <Id>[];
        for (final itemId in itemIds) {
          final matches = await _favoriteStore.getByItemId(itemId);
          if (matches.isEmpty) {
            continue;
          }
          toDelete.addAll(matches.map((collection) => collection.id));
        }

        if (toDelete.isNotEmpty) {
          await _favoriteStore.deleteByIds(toDelete);
        }
      });
    }, 'Failed to remove favorites');
  }

  /// Toggles [favorite] by removing it when already persisted or adding it otherwise.
  Future<void> toggleFavorite(FavoriteModel favorite) async {
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        final existing = await _favoriteStore.getByCompositeId(
          favorite.itemId,
          favorite.itemType,
        );
        if (existing != null) {
          await _favoriteStore.deleteById(existing.id);
          return;
        }
        final collection = await _mapModel(favorite);
        await _favoriteStore.put(collection);
      });
    }, 'Failed to toggle favorite');
  }

  /// Checks whether [itemId] is marked as favorite optionally scoping by [type].
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType? type,
  }) async {
    await _ensureReady();
    if (type != null) {
      final existing = await _favoriteStore.getByCompositeId(itemId, type);
      return existing != null;
    }
    final matches = await _favoriteStore.getByItemId(itemId);
    return matches.isNotEmpty;
  }

  /// Retrieves favorites filtered by [type].
  Future<List<FavoriteModel>> getFavoritesByType(
    FavoriteItemType type, {
    bool newestFirst = true,
  }) async {
    await _ensureReady();
    try {
      final collections = await _favoriteStore.getByType(type);
      collections.sort(
        (a, b) => newestFirst
            ? b.addedAt.compareTo(a.addedAt)
            : a.addedAt.compareTo(b.addedAt),
      );
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load favorites by type: $error'),
        stackTrace,
      );
    }
  }

  /// Retrieves favorites created after [threshold].
  Future<List<FavoriteModel>> getFavoritesAddedAfter(
    DateTime threshold, {
    FavoriteItemType? type,
  }) async {
    await _ensureReady();
    try {
      final collections =
          await _favoriteStore.getAddedAfter(threshold, type: type);
      collections.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load recent favorites: $error'),
        stackTrace,
      );
    }
  }

  /// Convenience accessor returning IDs for all favorited media items.
  Future<List<String>> getFavoriteMediaIds() async {
    await _ensureReady();
    final mediaFavorites =
        await getFavoritesByType(FavoriteItemType.media, newestFirst: false);
    return mediaFavorites
        .map((favorite) => favorite.itemId)
        .toList(growable: false);
  }

  Future<List<FavoriteCollection>> _mapModels(
    List<FavoriteModel> favorites,
  ) async {
    if (favorites.isEmpty) {
      return const <FavoriteCollection>[];
    }
    await _ensureReady();
    final mapped = <FavoriteCollection>[];
    for (final favorite in favorites) {
      mapped.add(await _mapModel(favorite));
    }
    return mapped;
  }

  Future<FavoriteCollection> _mapModel(FavoriteModel favorite) async {
    await _ensureReady();
    final collection = favorite.toCollection();
    switch (favorite.itemType) {
      case FavoriteItemType.media:
        collection.media.value =
            await _mediaStore.getByMediaId(favorite.itemId);
        break;
      case FavoriteItemType.directory:
        collection.directory.value =
            await _directoryStore.getByDirectoryId(favorite.itemId);
        break;
    }
    return collection;
  }

  Future<void> _executeSafely(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await _ensureReady();
      await action();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('$errorMessage: $error'),
        stackTrace,
      );
    }
  }

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  static FavoriteCollectionStore _defaultFavoriteStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarFavoriteCollectionStore(database);
  }

  static MediaCollectionStore _defaultMediaStoreBuilder(IsarDatabase database) {
    return IsarMediaCollectionStore(database);
  }

  static DirectoryCollectionStore _defaultDirectoryStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarDirectoryCollectionStore(database);
  }

  String _favoriteKey(String itemId, FavoriteItemType type) =>
      '${type.name}::$itemId';
}

/// Contract abstracting access to persisted [FavoriteCollection] records.
abstract interface class FavoriteCollectionStore {
  Future<List<FavoriteCollection>> getAll();

  Future<void> putAll(List<FavoriteCollection> favorites);

  Future<void> put(FavoriteCollection favorite);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<void> deleteByIds(List<Id> ids);

  Future<FavoriteCollection?> getByCompositeId(
    String itemId,
    FavoriteItemType type,
  );

  Future<List<FavoriteCollection>> getByItemId(String itemId);

  Future<List<FavoriteCollection>> getByType(FavoriteItemType type);

  Future<List<FavoriteCollection>> getAddedAfter(
    DateTime threshold, {
    FavoriteItemType? type,
  });

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarFavoriteCollectionStore implements FavoriteCollectionStore {
  IsarFavoriteCollectionStore(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<FavoriteCollection> get _collection =>
      _isar.collection<FavoriteCollection>();

  @override
  Future<List<FavoriteCollection>> getAll() {
    return _collection.where().findAll();
  }

  @override
  Future<void> putAll(List<FavoriteCollection> favorites) async {
    await _collection.putAll(favorites);
  }

  @override
  Future<void> put(FavoriteCollection favorite) {
    return _collection.put(favorite);
  }

  @override
  Future<void> clear() async {
    await _collection.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    await _collection.delete(id);
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await _collection.deleteAll(ids);
  }

  @override
  Future<FavoriteCollection?> getByCompositeId(
    String itemId,
    FavoriteItemType type,
  ) {
    final key = '${type.name}::$itemId';
    final hash = sha256.convert(utf8.encode(key)).bytes;
    final id = hash.fold<int>(0, (prev, element) => prev + element);
    return _collection.get(id);
  }

  @override
  Future<List<FavoriteCollection>> getByItemId(String itemId) {
    return _collection.filter().itemIdEqualTo(itemId).findAll();
  }

  @override
  Future<List<FavoriteCollection>> getByType(FavoriteItemType type) {
    return _collection.filter().itemTypeEqualTo(type).findAll();
  }

  @override
  Future<List<FavoriteCollection>> getAddedAfter(
    DateTime threshold, {
    FavoriteItemType? type,
  }) {
    var query =
        _collection.filter().addedAtGreaterThan(threshold, include: false);
    if (type != null) {
      query = query.itemTypeEqualTo(type);
    }
    return query.findAll();
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _isar.writeTxn(action);
  }
}
