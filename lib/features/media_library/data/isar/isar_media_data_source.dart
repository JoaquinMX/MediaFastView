import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../models/media_model.dart';
import 'isar_directory_data_source.dart';
import 'media_collection.dart';

/// Signature for building a [MediaCollectionStore] bound to the shared
/// [IsarDatabase] instance. Tests inject in-memory implementations via this
/// hook to avoid touching disk.
typedef MediaCollectionStoreBuilder = MediaCollectionStore Function(
  IsarDatabase database,
);

/// Data source that persists media records using Isar.
///
/// The implementation keeps parity with the
/// [SharedPreferencesMediaDataSource] API to ease incremental migration across
/// repositories and use cases. It leverages [DirectoryCollectionStore] to
/// attach link relationships while storing media records.
class IsarMediaDataSource {
  IsarMediaDataSource(
    this._database, {
    MediaCollectionStoreBuilder? mediaStoreBuilder,
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
  })  : _mediaStoreBuilder = mediaStoreBuilder ?? _defaultMediaStoreBuilder,
        _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder;

  final IsarDatabase _database;
  final MediaCollectionStoreBuilder _mediaStoreBuilder;
  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;

  late final MediaCollectionStore _mediaStore = _mediaStoreBuilder(_database);
  late final DirectoryCollectionStore _directoryStore =
      _directoryStoreBuilder(_database);

  /// Loads all persisted media entries.
  Future<List<MediaModel>> getMedia() async {
    await _ensureReady();
    final startTime = DateTime.now();
    try {
      final collections = await _mediaStore.getAll();
      final models = collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
      final totalTime = DateTime.now().difference(startTime);
      LoggingService.instance.info(
        'Loaded ${models.length} media items from Isar in '
        '${totalTime.inMilliseconds}ms',
      );
      return models;
    } catch (error, stackTrace) {
      final totalTime = DateTime.now().difference(startTime);
      LoggingService.instance.error(
        'Failed to load media after ${totalTime.inMilliseconds}ms: $error',
      );
      Error.throwWithStackTrace(
        PersistenceError('Failed to load media: $error'),
        stackTrace,
      );
    }
  }

  /// Persists [media] replacing any existing records.
  Future<void> saveMedia(List<MediaModel> media) async {
    await _executeSafely(() async {
      final collections = await _mapModels(media);
      await _mediaStore.writeTxn(() async {
        await _mediaStore.clear();
        if (collections.isNotEmpty) {
          await _mediaStore.putAll(collections);
        }
      });
    }, 'Failed to save media');
  }

  /// Upserts the provided [media] while keeping unmatched entries intact.
  Future<void> upsertMedia(List<MediaModel> media) async {
    await _executeSafely(() async {
      final collections = await _mapModels(media);
      if (collections.isEmpty) {
        return;
      }
      await _mediaStore.writeTxn(() async {
        for (final collection in collections) {
          await _mediaStore.put(collection);
        }
      });
    }, 'Failed to upsert media');
  }

  /// Retrieves media belonging to [directoryId].
  Future<List<MediaModel>> getMediaForDirectory(String directoryId) async {
    await _ensureReady();
    LoggingService.instance.debug(
      'getMediaForDirectory called with directoryId: $directoryId',
    );
    try {
      final collections = await _mediaStore.getByDirectoryId(directoryId);
      LoggingService.instance.debug(
        'filtered media has ${collections.length} items for directoryId: '
        '$directoryId',
      );
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load media for directory: $error'),
        stackTrace,
      );
    }
  }

  /// Adds new media records to the store.
  Future<void> addMedia(List<MediaModel> mediaItems) async {
    await _executeSafely(() async {
      final collections = await _mapModels(mediaItems);
      if (collections.isEmpty) {
        return;
      }
      await _mediaStore.writeTxn(() async {
        await _mediaStore.putAll(collections);
      });
    }, 'Failed to add media');
  }

  /// Replaces the tag set for the media entry identified by [mediaId].
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    await _executeSafely(() async {
      await _mediaStore.writeTxn(() async {
        final existing = await _mediaStore.getByMediaId(mediaId);
        if (existing == null) {
          return;
        }
        existing.tagIds = List<String>.from(tagIds);
        await _mediaStore.put(existing);
      });
    }, 'Failed to update media tags');
  }

  /// Updates tags for multiple media entries without rewriting the entire
  /// collection. Returns a [BatchUpdateResult] describing successes/failures.
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  ) async {
    if (mediaTags.isEmpty) {
      return BatchUpdateResult.empty;
    }

    await _ensureReady();

    try {
      final successes = <String>[];
      final failures = <String, String>{};
      final updatedCollections = <MediaCollection>[];

      for (final entry in mediaTags.entries) {
        final collection = await _mediaStore.getByMediaId(entry.key);
        if (collection == null) {
          failures[entry.key] = 'Media not found';
          continue;
        }

        collection.tagIds = List<String>.from(entry.value);
        updatedCollections.add(collection);
        successes.add(entry.key);
      }

      if (updatedCollections.isNotEmpty) {
        await _mediaStore.writeTxn(() async {
          for (final collection in updatedCollections) {
            await _mediaStore.put(collection);
          }
        });
      }

      return BatchUpdateResult(
        successfulIds: successes,
        failureReasons: failures,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to update media tags: $error'),
        stackTrace,
      );
    }
  }

  /// Removes every media record associated with [directoryId].
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _executeSafely(() async {
      final collections = await _mediaStore.getByDirectoryId(directoryId);
      if (collections.isEmpty) {
        return;
      }
      await _mediaStore.writeTxn(() async {
        final ids =
            collections.map<Id>((collection) => collection.id).toList();
        await _mediaStore.deleteByIds(ids);
      });
    }, 'Failed to remove media for directory');
  }

  /// Rewrites media entries that reference [legacyDirectoryId] so that they now
  /// point at [stableDirectoryId].
  Future<void> migrateDirectoryId(
    String legacyDirectoryId,
    String stableDirectoryId,
  ) async {
    if (legacyDirectoryId == stableDirectoryId) {
      return;
    }

    await _executeSafely(() async {
      final legacyCollections =
          await _mediaStore.getByDirectoryId(legacyDirectoryId);
      if (legacyCollections.isEmpty) {
        return;
      }

      final stableDirectory =
          await _directoryStore.getByDirectoryId(stableDirectoryId);

      await _mediaStore.writeTxn(() async {
        for (final collection in legacyCollections) {
          collection.directoryId = stableDirectoryId;
          collection.directory.value = stableDirectory;
          await _mediaStore.put(collection);
        }
      });
    }, 'Failed to migrate media directory references');
  }

  /// Moves the record for [mediaId] to a new location, keeping its identity.
  ///
  /// Used when a transfer left the media id intact (a same-volume move that
  /// kept the file name). The tags live on this row, so updating it in place is
  /// what preserves them — a rescan of the destination would otherwise find no
  /// row for the arriving file and reset its tags to empty.
  Future<void> relocateMedia({
    required String mediaId,
    required String newPath,
    required String newName,
    required String newDirectoryId,
    int? newSize,
    DateTime? newLastModified,
  }) async {
    await _executeSafely(() async {
      final existing = await _mediaStore.getByMediaId(mediaId);
      if (existing == null) {
        LoggingService.instance.warning(
          'Cannot relocate media $mediaId: no persisted record',
        );
        return;
      }

      await _warnIfPathTaken(newPath, byMediaId: mediaId);

      final directory = await _directoryStore.getByDirectoryId(newDirectoryId);
      await _mediaStore.writeTxn(() async {
        existing.path = newPath;
        existing.name = newName;
        existing.directoryId = newDirectoryId;
        existing.directory.value = directory;
        if (newSize != null) existing.size = newSize;
        if (newLastModified != null) existing.lastModified = newLastModified;
        await _mediaStore.put(existing);
      });
    }, 'Failed to relocate media');
  }

  /// Re-keys the record for [oldMediaId] onto [newMedia].
  ///
  /// Used when a transfer changed the media id (a cross-volume move, or one
  /// renamed to avoid a collision — the file name is part of the id). The Isar
  /// primary key is derived from the media id, so this is a delete plus an
  /// insert rather than an update. The caller is responsible for carrying the
  /// tags over on [newMedia].
  Future<void> replaceMedia({
    required String oldMediaId,
    required MediaModel newMedia,
  }) async {
    await replaceMediaBatch([
      (oldMediaId: oldMediaId, newMedia: newMedia),
    ]);
  }

  /// Batch form of [replaceMedia], for re-keying a moved directory's subtree.
  Future<void> replaceMediaBatch(
    List<({String oldMediaId, MediaModel newMedia})> entries,
  ) async {
    if (entries.isEmpty) {
      return;
    }

    await _executeSafely(() async {
      final collections = <MediaCollection>[];
      final staleIds = <Id>[];

      for (final entry in entries) {
        await _warnIfPathTaken(
          entry.newMedia.path,
          byMediaId: entry.newMedia.id,
        );

        final collection = entry.newMedia.toCollection();
        collection.directory.value = await _directoryStore.getByDirectoryId(
          entry.newMedia.directoryId,
        );
        collections.add(collection);

        // When the id survived the transfer the old and new rows are the same
        // record, so there is nothing to delete.
        if (entry.oldMediaId != entry.newMedia.id) {
          staleIds.add(mediaCollectionIdFromMediaId(entry.oldMediaId));
        }
      }

      await _mediaStore.writeTxn(() async {
        await _mediaStore.deleteByIds(staleIds);
        for (final collection in collections) {
          await _mediaStore.put(collection);
        }
      });
    }, 'Failed to replace media');
  }

  /// Loads every persisted record living under [directoryPath].
  ///
  /// Needed after a directory move: its descendants' paths and directory ids are
  /// all stale, and they are not reachable by directory id alone (an untracked
  /// subdirectory's children carry the *root's* directory id).
  Future<List<MediaModel>> getMediaUnderPath(String directoryPath) async {
    await _ensureReady();
    try {
      final all = await _mediaStore.getAll();
      return all
          .where((collection) => p.isWithin(directoryPath, collection.path))
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load media under path: $error'),
        stackTrace,
      );
    }
  }

  /// `path` is a unique index with `replace: true`, so writing a row whose path
  /// already belongs to a *different* record silently deletes that record. A
  /// miscomputed destination path would therefore destroy data instead of
  /// failing, which is worth a loud log.
  Future<void> _warnIfPathTaken(String path, {required String byMediaId}) async {
    final occupant = await _mediaStore.getByPath(path);
    if (occupant != null && occupant.mediaId != byMediaId) {
      LoggingService.instance.warning(
        'Writing media $byMediaId to $path will replace existing record '
        '${occupant.mediaId} held at the same path',
      );
    }
  }

  /// Removes every persisted media entry.
  Future<void> clearMedia() async {
    await _executeSafely(
      () async => _mediaStore.clear(),
      'Failed to clear media cache',
    );
  }

  /// Removes media whose [directoryId] values are absent from [directoryIds],
  /// leaving entries (and their tag assignments) for known directories intact.
  Future<void> removeMediaNotInDirectories(List<String> directoryIds) async {
    if (directoryIds.isEmpty) {
      return;
    }

    await _executeSafely(() async {
      final allowedIds = directoryIds.toSet();
      final allMedia = await _mediaStore.getAll();
      final orphanedIds = allMedia
          .where((media) => !allowedIds.contains(media.directoryId))
          .map((media) => media.id)
          .toList(growable: false);

      await _mediaStore.writeTxn(() async {
        await _mediaStore.deleteByIds(orphanedIds);
      });
    }, 'Failed to prune orphaned media cache');
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

  Future<List<MediaCollection>> _mapModels(List<MediaModel> media) async {
    if (media.isEmpty) {
      return const <MediaCollection>[];
    }

    final collections = <MediaCollection>[];
    for (final model in media) {
      final collection = model.toCollection();
      final directory = await _directoryStore.getByDirectoryId(model.directoryId);
      collection.directory.value = directory;
      collections.add(collection);
    }
    return collections;
  }

  static DirectoryCollectionStore _defaultDirectoryStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarDirectoryCollectionStore(database);
  }

  static MediaCollectionStore _defaultMediaStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarMediaCollectionStore(database);
  }
}

/// Abstraction for interacting with persisted [MediaCollection] objects.
abstract interface class MediaCollectionStore {
  Future<List<MediaCollection>> getAll();

  Future<void> putAll(List<MediaCollection> media);

  Future<void> put(MediaCollection media);

  Future<void> clear();

  Future<MediaCollection?> getById(Id id);

  Future<MediaCollection?> getByMediaId(String mediaId);

  /// Looks up the record currently occupying [path]. Case-insensitive, matching
  /// the unique index on `MediaCollection.path`.
  Future<MediaCollection?> getByPath(String path);

  Future<List<MediaCollection>> getByDirectoryId(String directoryId);

  Future<void> deleteByIds(List<Id> ids);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarMediaCollectionStore implements MediaCollectionStore {
  IsarMediaCollectionStore(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<MediaCollection> get _collection =>
      _isar.collection<MediaCollection>();

  @override
  Future<List<MediaCollection>> getAll() {
    return _collection.where().findAll();
  }

  @override
  Future<void> putAll(List<MediaCollection> media) async {
    await _collection.putAll(media);
  }

  @override
  Future<void> put(MediaCollection media) {
    return _collection.put(media);
  }

  @override
  Future<void> clear() async {
    await _isar.writeTxn(() async => _collection.clear());
  }

  @override
  Future<MediaCollection?> getById(Id id) {
    return _collection.get(id);
  }

  @override
  Future<MediaCollection?> getByMediaId(String mediaId) {
    return _collection.get(mediaCollectionIdFromMediaId(mediaId));
  }

  @override
  Future<MediaCollection?> getByPath(String path) {
    return _collection
        .filter()
        .pathEqualTo(path, caseSensitive: false)
        .findFirst();
  }

  @override
  Future<List<MediaCollection>> getByDirectoryId(String directoryId) {
    return _collection
        .filter()
        .directoryIdEqualTo(directoryId)
        .findAll();
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await _collection.deleteAll(ids);
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _isar.writeTxn(action);
  }
}
