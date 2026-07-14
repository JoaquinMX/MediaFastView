import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/profiles/data/isar/isar_profile_data_source.dart';
import 'package:media_fast_view/features/profiles/data/isar/profile_collection.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_saved_filter_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/saved_filter_collection.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

import 'isar_id.dart';


/// An [IsarDatabase] that reports itself open but is never actually touched —
/// the in-memory stores below stand in for every collection.
class FakeIsarDatabase extends IsarDatabase {
  FakeIsarDatabase() : super(schemas: const [], openIsar: _throwingOpen);

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

class InMemoryDirectoryCollectionStore implements DirectoryCollectionStore {
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
    for (final directory in _data.values) {
      if (directory.directoryId == directoryId) {
        return _clone(directory);
      }
    }
    return null;
  }

  @override
  Future<DirectoryCollection?> getByPath(String path) async {
    for (final directory in _data.values) {
      if (directory.path.toLowerCase() == path.toLowerCase()) {
        return _clone(directory);
      }
    }
    return null;
  }

  @override
  Future<List<DirectoryCollection>> getByProfileId(String profileId) async {
    return _data.values
        .where((directory) => directory.profileIds.contains(profileId))
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(DirectoryCollection directory) async {
    // Key by the collection's own Isar id getter rather than recomputing it, so
    // `deleteById` lines up with whatever id production hands us.
    _data[directory.id] = _clone(directory);
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

class InMemoryMediaCollectionStore implements MediaCollectionStore {
  final Map<String, MediaCollection> _data = <String, MediaCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    // Production `MediaCollection.id` is computed via
    // `mediaCollectionIdFromMediaId(mediaId)`, not `isarIdForString(mediaId)`.
    // Use the same function so this fake matches what production hands us.
    _data.removeWhere(
      (key, _) => ids.contains(mediaCollectionIdFromMediaId(key)),
    );
  }

  @override
  Future<List<MediaCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<MediaCollection?> getById(Id id) async {
    // Match production: id is `mediaCollectionIdFromMediaId(mediaId)`.
    for (final entry in _data.entries) {
      if (mediaCollectionIdFromMediaId(entry.key) == id) {
        return _clone(entry.value);
      }
    }
    return null;
  }

  @override
  Future<MediaCollection?> getByMediaId(String mediaId) async {
    final media = _data[mediaId];
    return media != null ? _clone(media) : null;
  }

  @override
  Future<MediaCollection?> getByPath(String path) async {
    for (final media in _data.values) {
      if (media.path.toLowerCase() == path.toLowerCase()) {
        return _clone(media);
      }
    }
    return null;
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
    // `path` is a unique index with `replace: true`, so a write evicts whatever
    // other record held that path. Reproducing it here is what lets tests catch
    // a miscomputed destination path silently destroying a row.
    _data.removeWhere(
      (mediaId, existing) =>
          mediaId != media.mediaId &&
          existing.path.toLowerCase() == media.path.toLowerCase(),
    );
    _data[media.mediaId] = _clone(media);
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

/// In-memory [TagCollectionStore].
///
/// Keyed by Isar id exactly as the real collection is, so a test can seed rows
/// under *legacy* ids (via [seedAt]) and prove the key migration rescues them.
class InMemoryTagCollectionStore implements TagCollectionStore {
  final Map<Id, TagCollection> data = <Id, TagCollection>{};

  /// Inserts [tag] at an explicit [id], bypassing the collection's own id
  /// derivation — the only way to model a row written by an older build.
  void seedAt(Id id, TagCollection tag) => data[id] = _clone(tag);

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> deleteById(Id id) async => data.remove(id);

  @override
  Future<TagCollection?> getById(Id id) async {
    final tag = data[id];
    return tag == null ? null : _clone(tag);
  }

  @override
  Future<List<TagCollection>> getAll() async =>
      data.values.map(_clone).toList(growable: false);

  @override
  Future<List<TagCollection>> getByProfileId(String profileId) async {
    return data.values
        .where((tag) => tag.profileId == profileId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> deleteByProfileId(String profileId) async {
    data.removeWhere((_, tag) => tag.profileId == profileId);
  }

  @override
  Future<TagCollection?> getByTagId(String tagId) async {
    final tag = data[isarIdForString(tagId)];
    return tag == null ? null : _clone(tag);
  }

  @override
  Future<List<TagCollection>> getByTagIds(List<String> tagIds) async {
    return tagIds
        .map((tagId) => data[isarIdForString(tagId)])
        .whereType<TagCollection>()
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(TagCollection tag) async => data[tag.id] = _clone(tag);

  @override
  Future<void> putAll(List<TagCollection> tags) async {
    for (final tag in tags) {
      await put(tag);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) => action();

  TagCollection _clone(TagCollection tag) => tag.toModel().toCollection();
}

/// In-memory [FavoriteCollectionStore]. See [InMemoryTagCollectionStore].
class InMemoryFavoriteCollectionStore implements FavoriteCollectionStore {
  final Map<Id, FavoriteCollection> data = <Id, FavoriteCollection>{};

  void seedAt(Id id, FavoriteCollection favorite) =>
      data[id] = _clone(favorite);

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> deleteById(Id id) async => data.remove(id);

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    for (final id in ids) {
      data.remove(id);
    }
  }

  @override
  Future<FavoriteCollection?> getById(Id id) async {
    final favorite = data[id];
    return favorite == null ? null : _clone(favorite);
  }

  @override
  Future<List<FavoriteCollection>> getAll() async =>
      data.values.map(_clone).toList(growable: false);

  @override
  Future<List<FavoriteCollection>> getByProfileId(String profileId) async {
    return data.values
        .where((favorite) => favorite.profileId == profileId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> deleteByProfileId(String profileId) async {
    data.removeWhere((_, favorite) => favorite.profileId == profileId);
  }

  @override
  Future<List<FavoriteCollection>> getAddedAfter(
    String profileId,
    DateTime threshold, {
    FavoriteItemType? type,
  }) async {
    return data.values
        .where((favorite) => favorite.profileId == profileId)
        .where((favorite) => favorite.addedAt.isAfter(threshold))
        .where((favorite) => type == null || favorite.itemType == type)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<FavoriteCollection?> getByCompositeId(
    String profileId,
    String itemId,
    FavoriteItemType type,
  ) async {
    final favorite =
        data[isarIdForString(favoriteKey(profileId, itemId, type))];
    return favorite == null ? null : _clone(favorite);
  }

  @override
  Future<List<FavoriteCollection>> getByItemId(
    String profileId,
    String itemId,
  ) async {
    return data.values
        .where((favorite) => favorite.profileId == profileId)
        .where((favorite) => favorite.itemId == itemId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<List<FavoriteCollection>> getByType(
    String profileId,
    FavoriteItemType type,
  ) async {
    return data.values
        .where((favorite) => favorite.profileId == profileId)
        .where((favorite) => favorite.itemType == type)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(FavoriteCollection favorite) async =>
      data[favorite.id] = _clone(favorite);

  @override
  Future<void> putAll(List<FavoriteCollection> favorites) async {
    for (final favorite in favorites) {
      await put(favorite);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) => action();

  FavoriteCollection _clone(FavoriteCollection favorite) {
    final clone = favorite.toModel().toCollection();
    clone.media.value = favorite.media.value;
    clone.directory.value = favorite.directory.value;
    return clone;
  }
}

/// In-memory [SavedFilterCollectionStore]. See [InMemoryTagCollectionStore].
class InMemorySavedFilterCollectionStore
    implements SavedFilterCollectionStore {
  final Map<Id, SavedFilterCollection> data = <Id, SavedFilterCollection>{};

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> deleteById(Id id) async => data.remove(id);

  @override
  Future<SavedFilterCollection?> getById(Id id) async {
    final filter = data[id];
    return filter == null ? null : _clone(filter);
  }

  @override
  Future<List<SavedFilterCollection>> getAll() async =>
      data.values.map(_clone).toList(growable: false);

  @override
  Future<List<SavedFilterCollection>> getByProfileId(String profileId) async {
    return data.values
        .where((filter) => filter.profileId == profileId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> deleteByProfileId(String profileId) async {
    data.removeWhere((_, filter) => filter.profileId == profileId);
  }

  @override
  Future<void> put(SavedFilterCollection filter) async =>
      data[filter.id] = _clone(filter);

  @override
  Future<void> putAll(List<SavedFilterCollection> filters) async {
    for (final filter in filters) {
      await put(filter);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) => action();

  SavedFilterCollection _clone(SavedFilterCollection filter) =>
      filter.toModel().toCollection();
}

/// In-memory [ProfileCollectionStore]. See [InMemoryTagCollectionStore].
class InMemoryProfileCollectionStore implements ProfileCollectionStore {
  final Map<Id, ProfileCollection> data = <Id, ProfileCollection>{};

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> deleteById(Id id) async => data.remove(id);

  @override
  Future<List<ProfileCollection>> getAll() async =>
      data.values.map(_clone).toList(growable: false);

  @override
  Future<void> put(ProfileCollection profile) async =>
      data[profile.id] = _clone(profile);

  @override
  Future<void> putAll(List<ProfileCollection> profiles) async {
    for (final profile in profiles) {
      await put(profile);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) => action();

  ProfileCollection _clone(ProfileCollection profile) =>
      profile.toModel().toCollection();
}
