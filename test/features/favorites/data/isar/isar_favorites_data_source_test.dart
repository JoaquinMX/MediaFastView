import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../../helpers/isar_id.dart';

class _FakeIsarDatabase extends IsarDatabase {
  _FakeIsarDatabase()
      : super(
          schemas: const [],
          openIsar: _throwingOpen,
        );

  static Future<Isar> _throwingOpen(
    List<CollectionSchema<dynamic>> schemas, {
    String? directory,
    String? name,
  }) async {
    throw UnimplementedError();
  }

  @override
  bool get isOpen => true;

  @override
  Isar get instance => throw UnimplementedError();
}

class _InMemoryFavoriteCollectionStore implements FavoriteCollectionStore {
  final Map<Id, FavoriteCollection> _data = <Id, FavoriteCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    _data.remove(id);
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    for (final id in ids) {
      _data.remove(id);
    }
  }

  @override
  Future<List<FavoriteCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<List<FavoriteCollection>> getAddedAfter(
    DateTime threshold, {
    FavoriteItemType? type,
  }) async {
    return _data.values
        .where((favorite) => favorite.addedAt.isAfter(threshold))
        .where((favorite) => type == null || favorite.itemType == type)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<FavoriteCollection?> getByCompositeId(
    String itemId,
    FavoriteItemType type,
  ) async {
    final favorite = _data[isarIdForString('${type.name}::$itemId')];
    return favorite == null ? null : _clone(favorite);
  }

  @override
  Future<List<FavoriteCollection>> getByItemId(String itemId) async {
    return _data.values
        .where((favorite) => favorite.itemId == itemId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<List<FavoriteCollection>> getByType(FavoriteItemType type) async {
    return _data.values
        .where((favorite) => favorite.itemType == type)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(FavoriteCollection favorite) async {
    _data[favorite.id] = _clone(favorite);
  }

  @override
  Future<void> putAll(List<FavoriteCollection> favorites) async {
    for (final favorite in favorites) {
      await put(favorite);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  FavoriteCollection _clone(FavoriteCollection favorite) {
    final clone = favorite.toModel().toCollection();
    clone.media.value = favorite.media.value;
    clone.directory.value = favorite.directory.value;
    return clone;
  }
}

class _InMemoryMediaCollectionStore implements MediaCollectionStore {
  final Map<Id, MediaCollection> _data = <Id, MediaCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    for (final id in ids) {
      _data.remove(id);
    }
  }

  @override
  Future<List<MediaCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<MediaCollection?> getById(Id id) async {
    final media = _data[id];
    return media == null ? null : _clone(media);
  }

  @override
  Future<List<MediaCollection>> getByDirectoryId(String directoryId) async {
    return _data.values
        .where((media) => media.directoryId == directoryId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(MediaCollection media) async {
    _data[isarIdForString(media.mediaId)] = _clone(media);
  }

  @override
  Future<void> putAll(List<MediaCollection> media) async {
    for (final item in media) {
      await put(item);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  MediaCollection _clone(MediaCollection media) {
    final clone = media.toModel().toCollection();
    clone.directory.value = media.directory.value;
    return clone;
  }
}

class _InMemoryDirectoryCollectionStore implements DirectoryCollectionStore {
  final Map<Id, DirectoryCollection> _data = <Id, DirectoryCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    _data.remove(id);
  }

  @override
  Future<List<DirectoryCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<DirectoryCollection?> getByDirectoryId(String directoryId) async {
    final directory = _data[isarIdForString(directoryId)];
    return directory == null ? null : _clone(directory);
  }

  @override
  Future<void> put(DirectoryCollection directory) async {
    _data[isarIdForString(directory.directoryId)] = _clone(directory);
  }

  @override
  Future<void> putAll(List<DirectoryCollection> directories) async {
    for (final directory in directories) {
      await put(directory);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  DirectoryCollection _clone(DirectoryCollection directory) {
    return directory.toModel().toCollection();
  }
}

void main() {
  group('IsarFavoritesDataSource', () {
    late _FakeIsarDatabase database;
    late _InMemoryFavoriteCollectionStore favoriteStore;
    late _InMemoryMediaCollectionStore mediaStore;
    late _InMemoryDirectoryCollectionStore directoryStore;
    late IsarFavoritesDataSource dataSource;

    setUp(() {
      database = _FakeIsarDatabase();
      favoriteStore = _InMemoryFavoriteCollectionStore();
      mediaStore = _InMemoryMediaCollectionStore();
      directoryStore = _InMemoryDirectoryCollectionStore();
      dataSource = IsarFavoritesDataSource(
        database,
        favoriteStoreBuilder: (_) => favoriteStore,
        mediaStoreBuilder: (_) => mediaStore,
        directoryStoreBuilder: (_) => directoryStore,
      );
    });

    FavoriteModel _buildFavorite(
      String id,
      FavoriteItemType type, {
      DateTime? addedAt,
    }) {
      return FavoriteModel(
        itemId: id,
        itemType: type,
        addedAt: addedAt ?? DateTime.utc(2024, 1, 1),
      );
    }

    MediaModel _buildMedia(String id, String directoryId) {
      return MediaModel(
        id: id,
        path: '/media/$id',
        name: 'Media $id',
        type: MediaType.image,
        size: 2048,
        lastModified: DateTime.utc(2024, 2, 1),
        directoryId: directoryId,
      );
    }

    DirectoryModel _buildDirectory(String id) {
      return DirectoryModel(
        id: id,
        path: '/dir/$id',
        name: 'Directory $id',
        lastModified: DateTime.utc(2024, 2, 1),
      );
    }

    Future<void> _seedMedia(List<MediaModel> media) async {
      await mediaStore.putAll(media.map((item) => item.toCollection()).toList());
    }

    Future<void> _seedDirectories(List<DirectoryModel> directories) async {
      await directoryStore
          .putAll(directories.map((dir) => dir.toCollection()).toList());
    }

    test('returns empty list when no favorites persisted', () async {
      final favorites = await dataSource.getFavorites();

      expect(favorites, isEmpty);
    });

    test('addFavorite stores favorite data', () async {
      final favorite = _buildFavorite('media-1', FavoriteItemType.media);

      await dataSource.addFavorite(favorite);

      final favorites = await dataSource.getFavorites();
      expect(favorites, equals(<FavoriteModel>[favorite]));
    });

    test('saveFavorites replaces existing entries', () async {
      await dataSource
          .saveFavorites(<FavoriteModel>[_buildFavorite('media-1', FavoriteItemType.media)]);

      final replacement = _buildFavorite('dir-1', FavoriteItemType.directory);
      await dataSource.saveFavorites(<FavoriteModel>[replacement]);

      final favorites = await dataSource.getFavorites();
      expect(favorites, equals(<FavoriteModel>[replacement]));
    });

    test('toggleFavorite removes existing entry', () async {
      final favorite = _buildFavorite('media-1', FavoriteItemType.media);
      await dataSource.addFavorite(favorite);

      await dataSource.toggleFavorite(favorite);

      final favorites = await dataSource.getFavorites();
      expect(favorites, isEmpty);
    });

    test('toggleFavorite adds entry when missing', () async {
      final favorite = _buildFavorite('media-1', FavoriteItemType.media);

      await dataSource.toggleFavorite(favorite);

      final favorites = await dataSource.getFavorites();
      expect(favorites, equals(<FavoriteModel>[favorite]));
    });

    test('removeFavorite deletes by type when provided', () async {
      final favoriteA = _buildFavorite('item-1', FavoriteItemType.media);
      final favoriteB = _buildFavorite('item-1', FavoriteItemType.directory);
      await dataSource.saveFavorites(<FavoriteModel>[favoriteA, favoriteB]);

      await dataSource.removeFavorite('item-1', type: FavoriteItemType.media);

      final favorites = await dataSource.getFavorites();
      expect(favorites, equals(<FavoriteModel>[favoriteB]));
    });

    test('removeFavorites deletes all matching IDs when type omitted', () async {
      final favoriteA = _buildFavorite('item-1', FavoriteItemType.media);
      final favoriteB = _buildFavorite('item-2', FavoriteItemType.media);
      await dataSource.saveFavorites(<FavoriteModel>[favoriteA, favoriteB]);

      await dataSource.removeFavorites(<String>['item-1']);

      final favorites = await dataSource.getFavorites();
      expect(favorites, equals(<FavoriteModel>[favoriteB]));
    });

    test('isFavorite honours optional type parameter', () async {
      final favorite = _buildFavorite('media-1', FavoriteItemType.media);
      await dataSource.addFavorite(favorite);

      final anyType = await dataSource.isFavorite('media-1');
      final matchingType =
          await dataSource.isFavorite('media-1', type: FavoriteItemType.media);
      final nonMatchingType =
          await dataSource.isFavorite('media-1', type: FavoriteItemType.directory);

      expect(anyType, isTrue);
      expect(matchingType, isTrue);
      expect(nonMatchingType, isFalse);
    });

    test('getFavoritesByType returns newest first when requested', () async {
      final oldFavorite = _buildFavorite(
        'media-1',
        FavoriteItemType.media,
        addedAt: DateTime.utc(2024, 1, 1),
      );
      final newFavorite = _buildFavorite(
        'media-2',
        FavoriteItemType.media,
        addedAt: DateTime.utc(2024, 2, 1),
      );
      await dataSource.saveFavorites(<FavoriteModel>[oldFavorite, newFavorite]);

      final favorites = await dataSource.getFavoritesByType(
        FavoriteItemType.media,
        newestFirst: true,
      );

      expect(favorites, equals(<FavoriteModel>[newFavorite, oldFavorite]));
    });

    test('getFavoritesAddedAfter filters by threshold and type', () async {
      final early = _buildFavorite(
        'media-1',
        FavoriteItemType.media,
        addedAt: DateTime.utc(2024, 1, 1),
      );
      final lateMedia = _buildFavorite(
        'media-2',
        FavoriteItemType.media,
        addedAt: DateTime.utc(2024, 3, 1),
      );
      final lateDirectory = _buildFavorite(
        'dir-1',
        FavoriteItemType.directory,
        addedAt: DateTime.utc(2024, 3, 1),
      );
      await dataSource.saveFavorites(<FavoriteModel>[early, lateMedia, lateDirectory]);

      final favorites = await dataSource.getFavoritesAddedAfter(
        DateTime.utc(2024, 2, 1),
        type: FavoriteItemType.media,
      );

      expect(favorites, equals(<FavoriteModel>[lateMedia]));
    });

    test('getFavoriteMediaIds returns IDs for media favorites', () async {
      final mediaFavorite = _buildFavorite('media-1', FavoriteItemType.media);
      final directoryFavorite =
          _buildFavorite('dir-1', FavoriteItemType.directory);
      await dataSource
          .saveFavorites(<FavoriteModel>[mediaFavorite, directoryFavorite]);

      final ids = await dataSource.getFavoriteMediaIds();

      expect(ids, equals(<String>['media-1']));
    });

    test('mapping attaches links when available', () async {
      final directory = _buildDirectory('dir-1');
      final media = _buildMedia('media-1', directory.id);
      await _seedDirectories(<DirectoryModel>[directory]);
      await _seedMedia(<MediaModel>[media]);

      final favoriteMedia = _buildFavorite('media-1', FavoriteItemType.media);
      final favoriteDirectory =
          _buildFavorite('dir-1', FavoriteItemType.directory);

      await dataSource.saveFavorites(
        <FavoriteModel>[favoriteMedia, favoriteDirectory],
      );

      final stored = await favoriteStore.getAll();

      expect(stored.firstWhere((fav) => fav.itemType == FavoriteItemType.media).media.value,
          isNotNull);
      expect(
        stored
            .firstWhere((fav) => fav.itemType == FavoriteItemType.directory)
            .directory
            .value,
        isNotNull,
      );
    });
  });
}
