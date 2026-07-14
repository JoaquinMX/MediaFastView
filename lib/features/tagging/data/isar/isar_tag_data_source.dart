import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/isar_directory_data_source.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../../media_library/data/models/tag_model.dart';
import 'tag_collection.dart';

/// Signature for building a [TagCollectionStore] bound to an [IsarDatabase].
typedef TagCollectionStoreBuilder = TagCollectionStore Function(
  IsarDatabase database,
);

/// Provides CRUD access to [TagCollection] entries and resolves tag assignments
/// for directories and media stored in Isar.
class IsarTagDataSource {
  IsarTagDataSource(
    this._database, {
    required this.profileId,
    TagCollectionStoreBuilder? tagStoreBuilder,
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
    MediaCollectionStoreBuilder? mediaStoreBuilder,
  })  : _tagStoreBuilder = tagStoreBuilder ?? _defaultTagStoreBuilder,
        _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder,
        _mediaStoreBuilder = mediaStoreBuilder ?? _defaultMediaStoreBuilder;

  final IsarDatabase _database;

  /// The profile whose tag vocabulary this data source reads and writes.
  final String profileId;

  final TagCollectionStoreBuilder _tagStoreBuilder;
  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;
  final MediaCollectionStoreBuilder _mediaStoreBuilder;

  late final TagCollectionStore _tagStore = _tagStoreBuilder(_database);
  late final DirectoryCollectionStore _directoryStore =
      _directoryStoreBuilder(_database);
  late final MediaCollectionStore _mediaStore = _mediaStoreBuilder(_database);

  /// Retrieves this profile's tags.
  Future<List<TagModel>> getTags() async {
    await _ensureReady();
    try {
      final collections = await _tagStore.getByProfileId(profileId);
      collections.sort((a, b) => a.name.compareTo(b.name));
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load tags: $error'),
        stackTrace,
      );
    }
  }

  /// Replaces this profile's tags with [tags].
  ///
  /// Deletes by profile rather than clearing the collection — a bare `clear()`
  /// here would wipe every other profile's vocabulary too.
  Future<void> saveTags(List<TagModel> tags) async {
    final collections = tags.map(_stamped).toList();
    await _executeSafely(() async {
      await _tagStore.writeTxn(() async {
        await _tagStore.deleteByProfileId(profileId);
        if (collections.isNotEmpty) {
          await _tagStore.putAll(collections);
        }
      });
    }, 'Failed to save tags');
  }

  /// Adds a new [tag] to this profile.
  Future<void> addTag(TagModel tag) async {
    await _executeSafely(() async {
      await _tagStore.writeTxn(() async {
        await _tagStore.put(_stamped(tag));
      });
    }, 'Failed to add tag');
  }

  /// Updates the persisted representation of [tag].
  Future<void> updateTag(TagModel tag) async {
    await _executeSafely(() async {
      await _tagStore.writeTxn(() async {
        await _tagStore.put(_stamped(tag));
      });
    }, 'Failed to update tag');
  }

  /// Removes the tag identified by [id].
  Future<void> removeTag(String id) async {
    await _executeSafely(() async {
      await _tagStore.writeTxn(() async {
        await _tagStore.deleteById(tagCollectionIdFromTagId(id));
      });
    }, 'Failed to remove tag');
  }

  /// Removes this profile's tags, leaving other profiles' vocabularies alone.
  Future<void> clearTags() async {
    await _executeSafely(() async {
      await _tagStore.writeTxn(() async {
        await _tagStore.deleteByProfileId(profileId);
      });
    }, 'Failed to clear tags');
  }

  /// Binds [tag] to this data source's profile before it is persisted.
  ///
  /// The caller never supplies the owner: a tag written through this data source
  /// belongs to this profile by construction.
  TagCollection _stamped(TagModel tag) =>
      tag.copyWith(profileId: profileId).toCollection();

  /// Resolves the tags assigned to the media entry identified by [mediaId].
  Future<List<TagModel>> getTagsForMedia(String mediaId) async {
    await _ensureReady();
    try {
      final media = await _mediaStore.getByMediaId(mediaId);
      if (media == null || media.tagIds.isEmpty) {
        return const <TagModel>[];
      }
      return _resolveTagsForIds(media.tagIds);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load media tags: $error'),
        stackTrace,
      );
    }
  }

  /// Resolves the tags assigned to the directory identified by [directoryId].
  Future<List<TagModel>> getTagsForDirectory(String directoryId) async {
    await _ensureReady();
    try {
      final directory = await _directoryStore.getByDirectoryId(directoryId);
      if (directory == null || directory.tagIds.isEmpty) {
        return const <TagModel>[];
      }
      return _resolveTagsForIds(directory.tagIds);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directory tags: $error'),
        stackTrace,
      );
    }
  }

  Future<List<TagModel>> _resolveTagsForIds(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return const <TagModel>[];
    }
    final collections = await _tagStore.getByTagIds(tagIds);
    if (collections.isEmpty) {
      return const <TagModel>[];
    }
    // A directory or media row shared between profiles carries tag ids from all
    // of them, so drop the ones this profile does not own.
    final mapped = <String, TagCollection>{
      for (final collection in collections)
        if (collection.profileId == profileId) collection.tagId: collection,
    };
    return tagIds
        .where(mapped.containsKey)
        .map((tagId) => mapped[tagId]!.toModel())
        .toList(growable: false);
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

  static TagCollectionStore _defaultTagStoreBuilder(IsarDatabase database) {
    return IsarTagCollectionStore(database);
  }

  static DirectoryCollectionStore _defaultDirectoryStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarDirectoryCollectionStore(database);
  }

  static MediaCollectionStore _defaultMediaStoreBuilder(IsarDatabase database) {
    return IsarMediaCollectionStore(database);
  }
}

/// Contract abstracting access to persisted [TagCollection] records.
abstract interface class TagCollectionStore {
  /// Every row in the collection, across all profiles.
  ///
  /// For the migrations. Application reads want [getByProfileId].
  Future<List<TagCollection>> getAll();

  Future<List<TagCollection>> getByProfileId(String profileId);

  Future<void> putAll(List<TagCollection> tags);

  Future<void> put(TagCollection tag);

  Future<void> clear();

  Future<void> deleteById(Id id);

  /// Deletes every tag owned by [profileId].
  Future<void> deleteByProfileId(String profileId);

  /// Looks a row up by its Isar primary key.
  ///
  /// Used by the key migration to tell a row stored under the legacy id from one
  /// already stored under the current one.
  Future<TagCollection?> getById(Id id);

  Future<TagCollection?> getByTagId(String tagId);

  Future<List<TagCollection>> getByTagIds(List<String> tagIds);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarTagCollectionStore implements TagCollectionStore {
  IsarTagCollectionStore(IsarDatabase database)
    : _resolveIsar = (() => database.instance);

  /// Binds to an already-open [Isar] directly.
  ///
  /// For the key migration, which runs inside `IsarDatabase.open()` before the
  /// instance is published — so `database.instance` would still throw.
  IsarTagCollectionStore.forIsar(Isar isar) : _resolveIsar = (() => isar);

  final Isar Function() _resolveIsar;

  Isar get _isar => _resolveIsar();

  IsarCollection<TagCollection> get _collection =>
      _isar.collection<TagCollection>();

  @override
  Future<List<TagCollection>> getAll() {
    return _collection.where().findAll();
  }

  @override
  Future<List<TagCollection>> getByProfileId(String profileId) {
    return _collection.filter().profileIdEqualTo(profileId).findAll();
  }

  @override
  Future<void> putAll(List<TagCollection> tags) async {
    await _collection.putAll(tags);
  }

  @override
  Future<void> put(TagCollection tag) {
    return _collection.put(tag);
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
  Future<void> deleteByProfileId(String profileId) async {
    await _collection.filter().profileIdEqualTo(profileId).deleteAll();
  }

  @override
  Future<TagCollection?> getById(Id id) => _collection.get(id);

  @override
  Future<TagCollection?> getByTagId(String tagId) {
    return _collection.filter().tagIdEqualTo(tagId).findFirst();
  }

  @override
  Future<List<TagCollection>> getByTagIds(List<String> tagIds) {
    if (tagIds.isEmpty) {
      return Future.value(const <TagCollection>[]);
    }
    return _collection
        .where()
        .anyOf(tagIds, (query, tagId) => query.tagIdEqualTo(tagId))
        .findAll();
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _isar.writeTxn(action);
  }
}
