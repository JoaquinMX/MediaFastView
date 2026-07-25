import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../media_library/data/isar/isar_directory_data_source.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../models/favorite_model.dart';
import 'favorite_collection.dart';

/// Signature for constructing a [FavoriteCollectionStore] bound to Isar.
typedef FavoriteCollectionStoreBuilder = FavoriteCollectionStore Function(
  IsarDatabase database,
);

/// Data source that persists favorites using Isar collections.
///
/// Bound to a single profile: every read is scoped to [profileId] and every
/// write is stamped with it, so a favorite cannot land in the wrong profile.
class IsarFavoritesDataSource {
  IsarFavoritesDataSource(
    this._database, {
    required this.profileId,
    FavoriteCollectionStoreBuilder? favoriteStoreBuilder,
    MediaCollectionStoreBuilder? mediaStoreBuilder,
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
  })  : _favoriteStoreBuilder =
            favoriteStoreBuilder ?? _defaultFavoriteStoreBuilder,
        _mediaStoreBuilder = mediaStoreBuilder ?? _defaultMediaStoreBuilder,
        _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder;

  final IsarDatabase _database;

  /// The profile this data source reads and writes favorites for.
  final String profileId;

  final FavoriteCollectionStoreBuilder _favoriteStoreBuilder;
  final MediaCollectionStoreBuilder _mediaStoreBuilder;
  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;

  late final FavoriteCollectionStore _favoriteStore =
      _favoriteStoreBuilder(_database);
  late final MediaCollectionStore _mediaStore = _mediaStoreBuilder(_database);
  late final DirectoryCollectionStore _directoryStore =
      _directoryStoreBuilder(_database);

  /// Retrieves this profile's favorites sorted by creation time.
  Future<List<FavoriteModel>> getFavorites() async {
    await _ensureReady();
    try {
      final collections = await _favoriteStore.getByProfileId(profileId);
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

  /// Persists [favorites], replacing this profile's existing records.
  ///
  /// Deletes by profile rather than clearing the collection — a bare `clear()`
  /// here would wipe every other profile's favorites too.
  Future<void> saveFavorites(List<FavoriteModel> favorites) async {
    final collections = await _mapModels(favorites);
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        await _favoriteStore.deleteByProfileId(profileId);
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
              .map((itemId) => favoriteCollectionId(profileId, itemId, type))
              .toList(growable: false);
          await _favoriteStore.deleteByIds(ids);
          return;
        }

        final toDelete = <Id>[];
        for (final itemId in itemIds) {
          final matches = await _favoriteStore.getByItemId(profileId, itemId);
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

  /// Removes this profile's favorites, leaving other profiles' alone.
  Future<void> clearFavorites() async {
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        await _favoriteStore.deleteByProfileId(profileId);
      });
    }, 'Failed to clear favorites');
  }

  /// Toggles [favorite] by removing it when already persisted or adding it otherwise.
  Future<void> toggleFavorite(FavoriteModel favorite) async {
    await _executeSafely(() async {
      await _favoriteStore.writeTxn(() async {
        final existing = await _favoriteStore.getByCompositeId(
          profileId,
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
      final existing =
          await _favoriteStore.getByCompositeId(profileId, itemId, type);
      return existing != null;
    }
    final matches = await _favoriteStore.getByItemId(profileId, itemId);
    return matches.isNotEmpty;
  }

  /// Retrieves favorites filtered by [type].
  Future<List<FavoriteModel>> getFavoritesByType(
    FavoriteItemType type, {
    bool newestFirst = true,
  }) async {
    await _ensureReady();
    try {
      final collections = await _favoriteStore.getByType(profileId, type);
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
          await _favoriteStore.getAddedAfter(profileId, threshold, type: type);
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

  /// Convenience accessor returning IDs for all favorited directories.
  Future<List<String>> getFavoriteDirectoryIds() async {
    await _ensureReady();
    final directoryFavorites = await getFavoritesByType(
      FavoriteItemType.directory,
      newestFirst: false,
    );
    return directoryFavorites
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
    // Stamped here rather than trusted from the caller: the profile is part of
    // the row's primary key, so a model that arrived without one — or with a
    // stale one — would be written under the wrong id.
    final collection = favorite.copyWith(profileId: profileId).toCollection();
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

}

/// Contract abstracting access to persisted [FavoriteCollection] records.
abstract interface class FavoriteCollectionStore {
  /// Every row in the collection, across all profiles.
  ///
  /// For the migrations, which have to see and re-key rows regardless of which
  /// profile owns them. Application reads want [getByProfileId].
  Future<List<FavoriteCollection>> getAll();

  Future<List<FavoriteCollection>> getByProfileId(String profileId);

  Future<void> putAll(List<FavoriteCollection> favorites);

  Future<void> put(FavoriteCollection favorite);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<void> deleteByIds(List<Id> ids);

  /// Deletes every favorite owned by [profileId].
  Future<void> deleteByProfileId(String profileId);

  /// Looks a row up by its Isar primary key.
  ///
  /// Used by the key migration to tell a row stored under the legacy id from one
  /// already stored under the current one.
  Future<FavoriteCollection?> getById(Id id);

  Future<FavoriteCollection?> getByCompositeId(
    String profileId,
    String itemId,
    FavoriteItemType type,
  );

  Future<List<FavoriteCollection>> getByItemId(String profileId, String itemId);

  Future<List<FavoriteCollection>> getByType(
    String profileId,
    FavoriteItemType type,
  );

  Future<List<FavoriteCollection>> getAddedAfter(
    String profileId,
    DateTime threshold, {
    FavoriteItemType? type,
  });

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarFavoriteCollectionStore implements FavoriteCollectionStore {
  IsarFavoriteCollectionStore(IsarDatabase database)
    : _resolveIsar = (() => database.instance);

  /// Binds to an already-open [Isar] directly.
  ///
  /// For the key migration, which runs inside `IsarDatabase.open()` before the
  /// instance is published — so `database.instance` would still throw.
  IsarFavoriteCollectionStore.forIsar(Isar isar) : _resolveIsar = (() => isar);

  final Isar Function() _resolveIsar;

  Isar get _isar => _resolveIsar();

  IsarCollection<FavoriteCollection> get _collection =>
      _isar.collection<FavoriteCollection>();

  @override
  Future<List<FavoriteCollection>> getAll() {
    return _collection.where().findAll();
  }

  @override
  Future<List<FavoriteCollection>> getByProfileId(String profileId) {
    return _collection.filter().profileIdEqualTo(profileId).findAll();
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
  Future<void> deleteByProfileId(String profileId) async {
    await _collection.filter().profileIdEqualTo(profileId).deleteAll();
  }

  @override
  Future<FavoriteCollection?> getById(Id id) => _collection.get(id);

  @override
  Future<FavoriteCollection?> getByCompositeId(
    String profileId,
    String itemId,
    FavoriteItemType type,
  ) {
    return _collection.get(favoriteCollectionId(profileId, itemId, type));
  }

  @override
  Future<List<FavoriteCollection>> getByItemId(
    String profileId,
    String itemId,
  ) {
    return _collection
        .filter()
        .profileIdEqualTo(profileId)
        .itemIdEqualTo(itemId)
        .findAll();
  }

  @override
  Future<List<FavoriteCollection>> getByType(
    String profileId,
    FavoriteItemType type,
  ) {
    return _collection
        .filter()
        .profileIdEqualTo(profileId)
        .itemTypeEqualTo(type)
        .findAll();
  }

  @override
  Future<List<FavoriteCollection>> getAddedAfter(
    String profileId,
    DateTime threshold, {
    FavoriteItemType? type,
  }) {
    var query = _collection
        .filter()
        .profileIdEqualTo(profileId)
        .addedAtGreaterThan(threshold, include: false);
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
