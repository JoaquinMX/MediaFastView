import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../tagging/data/isar/isar_tag_data_source.dart';
import '../../../tagging/data/isar/tag_collection.dart';
import '../models/directory_model.dart';
import 'directory_collection.dart';

/// Signature for building a [DirectoryCollectionStore] bound to an
/// [IsarDatabase] instance. Exposed for tests to inject in-memory
/// implementations without relying on the real database runtime.
typedef DirectoryCollectionStoreBuilder = DirectoryCollectionStore Function(
  IsarDatabase database,
);

/// Provides CRUD access to [DirectoryCollection] entries persisted with Isar.
///
/// This data source mirrors the behaviour of the legacy
/// [SharedPreferencesDirectoryDataSource] so repositories can migrate without
/// large refactors. All operations run inside transactions to guarantee
/// consistency when multiple models are modified at once.
class IsarDirectoryDataSource {
  IsarDirectoryDataSource(
    this._database, {
    required this.profileId,
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
    TagCollectionStoreBuilder? tagStoreBuilder,
  })  : _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder,
        _tagStoreBuilder = tagStoreBuilder ?? _defaultTagStoreBuilder;

  final IsarDatabase _database;

  /// The profile whose directories and tag assignments this data source serves.
  final String profileId;

  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;
  final TagCollectionStoreBuilder _tagStoreBuilder;

  late final DirectoryCollectionStore _store = _directoryStoreBuilder(_database);
  late final TagCollectionStore _tagStore = _tagStoreBuilder(_database);

  /// Retrieves the directories belonging to this profile.
  Future<List<DirectoryModel>> getDirectories() async {
    await _ensureReady();
    try {
      final collections = await _store.getByProfileId(profileId);
      return _toScopedModels(collections);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directories: $error'),
        stackTrace,
      );
    }
  }

  /// Retrieves a single directory by its identifier.
  Future<DirectoryModel?> getDirectoryById(String directoryId) async {
    await _ensureReady();
    try {
      final collection = await _store.getByDirectoryId(directoryId);
      if (collection == null) {
        return null;
      }
      final scoped = await _toScopedModels(<DirectoryCollection>[collection]);
      return scoped.first;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directory $directoryId: $error'),
        stackTrace,
      );
    }
  }

  /// Retrieves a directory by its path, **regardless of which profile owns it**.
  ///
  /// Deliberately unscoped. Adding a folder has to find the row even when it is
  /// currently owned only by another profile: `path` is a unique replace index,
  /// so inserting a second row for the same folder would overwrite the first —
  /// destroying its bookmark, its scan cache and the other profile's tags. The
  /// caller unions the profile in instead.
  Future<DirectoryModel?> getDirectoryByPathUnscoped(String path) async {
    await _ensureReady();
    try {
      final collection = await _store.getByPath(path);
      return collection?.toModel();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directory at $path: $error'),
        stackTrace,
      );
    }
  }

  /// Replaces this profile's directories with [directories].
  Future<void> saveDirectories(List<DirectoryModel> directories) async {
    final collections =
        directories.map((directory) => directory.toCollection()).toList();
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _releaseProfileDirectories();
        if (collections.isNotEmpty) {
          await _store.putAll(collections);
        }
      });
    }, 'Failed to save directories');
  }

  /// Adds a new [directory] to persistence.
  Future<void> addDirectory(DirectoryModel directory) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.put(directory.toCollection());
      });
    }, 'Failed to add directory');
  }

  /// Removes the directory identified by [id].
  Future<void> removeDirectory(String id) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.deleteById(computeDirectoryCollectionId(id));
      });
    }, 'Failed to remove directory');
  }

  /// Updates the persisted representation of [updatedDirectory].
  ///
  /// The tag list merges rather than replaces, for the same reason
  /// [updateDirectoryTagsBatch] does: the row may be shared with another profile
  /// whose tag ids live in the same list.
  Future<void> updateDirectory(DirectoryModel updatedDirectory) async {
    await _executeSafely(() async {
      final collection = updatedDirectory.toCollection();
      final existing =
          await _store.getByDirectoryId(updatedDirectory.id);
      if (existing != null) {
        collection.tagIds = await _mergeTagIds(
          persisted: existing.tagIds,
          incoming: updatedDirectory.tagIds,
        );
      }
      await _store.writeTxn(() async {
        await _store.put(collection);
      });
    }, 'Failed to update directory');
  }

  /// Updates tags for multiple directories without wiping unrelated records.
  ///
  /// The incoming lists are this profile's tags for each directory. A directory
  /// shared with another profile also carries *its* tag ids in the same
  /// persisted list, so the write merges rather than replaces: the other
  /// profile's ids are preserved and only this profile's are swapped out.
  Future<BatchUpdateResult> updateDirectoryTagsBatch(
    Map<String, List<String>> directoryTags,
  ) async {
    if (directoryTags.isEmpty) {
      return BatchUpdateResult.empty;
    }

    await _ensureReady();

    try {
      final successes = <String>[];
      final failures = <String, String>{};
      final updatedCollections = <DirectoryCollection>[];

      for (final entry in directoryTags.entries) {
        final collection = await _store.getByDirectoryId(entry.key);
        if (collection == null) {
          failures[entry.key] = 'Directory not found';
          continue;
        }

        collection.tagIds = await _mergeTagIds(
          persisted: collection.tagIds,
          incoming: entry.value,
        );
        updatedCollections.add(collection);
        successes.add(entry.key);
      }

      if (updatedCollections.isNotEmpty) {
        await _store.writeTxn(() async {
          for (final collection in updatedCollections) {
            await _store.put(collection);
          }
        });
      }

      return BatchUpdateResult(
        successfulIds: successes,
        failureReasons: failures,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to update directory tags: $error'),
        stackTrace,
      );
    }
  }

  /// Drops this profile's directories, leaving other profiles' libraries intact.
  Future<void> clearDirectories() async {
    await _executeSafely(() async {
      await _store.writeTxn(_releaseProfileDirectories);
    }, 'Failed to clear directories');
  }

  /// Removes this profile from every directory it owns.
  ///
  /// A directory the profile shares with another survives with its bookmark and
  /// scan cache; one it owned alone is dropped from the library. Files on disk
  /// are never touched.
  Future<void> _releaseProfileDirectories() async {
    final owned = await _store.getByProfileId(profileId);
    if (owned.isEmpty) {
      return;
    }

    final ownTagIds = await _profileTagIds(
      owned.expand((collection) => collection.tagIds),
    );

    for (final collection in owned) {
      final remaining = collection.profileIds
          .where((id) => id != profileId)
          .toList(growable: false);

      if (remaining.isEmpty) {
        await _store.deleteById(collection.id);
        continue;
      }

      collection.profileIds = remaining;
      collection.tagIds = collection.tagIds
          .where((tagId) => !ownTagIds.contains(tagId))
          .toList(growable: false);
      await _store.put(collection);
    }
  }

  /// Rewrites [persisted] so this profile's tag ids become [incoming], leaving
  /// every other profile's ids on the row untouched.
  ///
  /// Tag ids that resolve to no tag at all are dropped: they are assignments to
  /// tags that have since been deleted, and nothing can render them.
  Future<List<String>> _mergeTagIds({
    required List<String> persisted,
    required List<String> incoming,
  }) async {
    if (persisted.isEmpty) {
      return List<String>.from(incoming);
    }

    final foreign = await _foreignTagIds(persisted);
    return <String>[
      ...persisted.where(foreign.contains),
      ...incoming.where((tagId) => !foreign.contains(tagId)),
    ];
  }

  /// The subset of [tagIds] owned by a profile other than this one.
  Future<Set<String>> _foreignTagIds(Iterable<String> tagIds) async {
    final rows = await _resolveTags(tagIds);
    return <String>{
      for (final row in rows)
        if (row.profileId != profileId) row.tagId,
    };
  }

  /// The subset of [tagIds] owned by this profile.
  Future<Set<String>> _profileTagIds(Iterable<String> tagIds) async {
    final rows = await _resolveTags(tagIds);
    return <String>{
      for (final row in rows)
        if (row.profileId == profileId) row.tagId,
    };
  }

  Future<List<TagCollection>> _resolveTags(Iterable<String> tagIds) async {
    final unique = tagIds.toSet().toList(growable: false);
    if (unique.isEmpty) {
      return const <TagCollection>[];
    }
    return _tagStore.getByTagIds(unique);
  }

  /// Maps [collections] to models with other profiles' tag ids hidden.
  ///
  /// Above the data layer, `DirectoryModel.tagIds` means "tags this profile can
  /// see on this directory" — so grids, counts and bulk dialogs never have to
  /// know that a shared directory carries foreign ids underneath.
  ///
  /// Only ids that resolve to a tag owned by *another* profile are removed. An id
  /// that resolves to nothing — an assignment to a tag that has since been
  /// deleted — is left alone: those were already tolerated before profiles
  /// existed, `TagLookup` drops them when it renders, and treating them as
  /// foreign here would mean a missing tag row could silently unassign tags.
  Future<List<DirectoryModel>> _toScopedModels(
    List<DirectoryCollection> collections,
  ) async {
    if (collections.isEmpty) {
      return const <DirectoryModel>[];
    }

    final foreign = await _foreignTagIds(
      collections.expand((collection) => collection.tagIds),
    );
    if (foreign.isEmpty) {
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    }

    return collections
        .map(
          (collection) => collection.toModel().copyWith(
                tagIds: collection.tagIds
                    .where((tagId) => !foreign.contains(tagId))
                    .toList(growable: false),
              ),
        )
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

  static DirectoryCollectionStore _defaultDirectoryStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarDirectoryCollectionStore(database);
  }

  static TagCollectionStore _defaultTagStoreBuilder(IsarDatabase database) {
    return IsarTagCollectionStore(database);
  }
}

/// Contract abstracting access to persisted [DirectoryCollection] records.
///
/// Defining this contract allows the production implementation to delegate to
/// Isar while tests can provide an in-memory variant without touching disk or
/// depending on code generation.
abstract interface class DirectoryCollectionStore {
  /// Every row in the collection, across all profiles.
  ///
  /// For the migrations. Application reads want [getByProfileId].
  Future<List<DirectoryCollection>> getAll();

  /// The directories belonging to [profileId].
  Future<List<DirectoryCollection>> getByProfileId(String profileId);

  Future<void> putAll(List<DirectoryCollection> directories);

  Future<void> put(DirectoryCollection directory);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<DirectoryCollection?> getByDirectoryId(String directoryId);

  /// Looks a row up by path, ignoring profile membership.
  ///
  /// `path` is a unique index, so this resolves the single shared row for a
  /// folder no matter which profiles currently track it.
  Future<DirectoryCollection?> getByPath(String path);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarDirectoryCollectionStore implements DirectoryCollectionStore {
  IsarDirectoryCollectionStore(IsarDatabase database)
      : _resolveIsar = (() => database.instance);

  /// Binds to an already-open [Isar] directly.
  ///
  /// For the profile migration, which runs inside `IsarDatabase.open()` before
  /// the instance is published — so `database.instance` would still throw.
  IsarDirectoryCollectionStore.forIsar(Isar isar) : _resolveIsar = (() => isar);

  final Isar Function() _resolveIsar;

  Isar get _isar => _resolveIsar();

  IsarCollection<DirectoryCollection> get _collection =>
      _isar.collection<DirectoryCollection>();

  @override
  Future<List<DirectoryCollection>> getAll() {
    return _collection.where().findAll();
  }

  @override
  Future<List<DirectoryCollection>> getByProfileId(String profileId) {
    return _collection
        .filter()
        .profileIdsElementEqualTo(profileId)
        .findAll();
  }

  @override
  Future<void> putAll(List<DirectoryCollection> directories) async {
    await _collection.putAll(directories);
  }

  @override
  Future<void> put(DirectoryCollection directory) {
    return _collection.put(directory);
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
  Future<DirectoryCollection?> getByDirectoryId(String directoryId) {
    return _collection.get(computeDirectoryCollectionId(directoryId));
  }

  @override
  Future<DirectoryCollection?> getByPath(String path) {
    // Case-insensitive to match the unique index on `path`, which is declared
    // `caseSensitive: false`. A case-sensitive lookup would miss the very row
    // that a subsequent put would collide with and replace.
    return _collection
        .filter()
        .pathEqualTo(path, caseSensitive: false)
        .findFirst();
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _isar.writeTxn(action);
  }
}
