import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../../../core/services/logging_service.dart';
import '../models/media_model.dart';
import 'directory_collection.dart';
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
        final existing = await _mediaStore.getById(Isar.fastHash(mediaId));
        if (existing == null) {
          return;
        }
        existing.tagIds
          ..clear()
          ..addAll(tagIds);
        await _mediaStore.put(existing);
      });
    }, 'Failed to update media tags');
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

  Future<void> _executeSafely(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('$errorMessage: $error'),
        stackTrace,
      );
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
    return _collection
        .where()
        .addWhereClause(const IdWhereClause.any())
        .findAll();
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
    await _collection.clear();
  }

  @override
  Future<MediaCollection?> getById(Id id) {
    return _collection.get(id);
  }

  @override
  Future<List<MediaCollection>> getByDirectoryId(String directoryId) {
    return _collection
        .filter()
        .addFilterCondition(
          FilterCondition.equalTo(
            property: r'directoryId',
            value: directoryId,
          ),
        )
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
