import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';
import 'directory_cover_collection.dart';

typedef DirectoryCoverCollectionStoreBuilder =
    DirectoryCoverCollectionStore Function(IsarDatabase database);

/// Provides profile-scoped persistence for custom directory covers.
class IsarDirectoryCoverDataSource {
  IsarDirectoryCoverDataSource(
    this._database, {
    required this.profileId,
    DirectoryCoverCollectionStoreBuilder? storeBuilder,
  }) : _storeBuilder = storeBuilder ?? _defaultStoreBuilder;

  final IsarDatabase _database;
  final String profileId;
  final DirectoryCoverCollectionStoreBuilder _storeBuilder;

  late final DirectoryCoverCollectionStore _store = _storeBuilder(_database);

  Future<DirectoryCoverEntity?> getCover(String directoryPath) async {
    await _ensureReady();
    try {
      final normalizedPath = _normalize(directoryPath);
      final cover = await _store.getByCoverKey(
        directoryCoverKey(profileId, normalizedPath),
      );
      return cover?.toEntity();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directory cover: $error'),
        stackTrace,
      );
    }
  }

  Future<void> saveCover(DirectoryCoverEntity cover) async {
    final normalizedPath = _normalize(cover.directoryPath);
    final collection = DirectoryCoverCollection(
      coverKey: directoryCoverKey(profileId, normalizedPath),
      profileId: profileId,
      directoryPath: normalizedPath,
      sourceFileName: cover.sourceFileName ?? '',
      mediaType: cover.mediaType ?? MediaType.image,
      mode: cover.mode,
      updatedAt: cover.updatedAt,
    );
    await _executeSafely(() async {
      await _store.writeTxn(() => _store.put(collection));
    }, 'Failed to save directory cover');
  }

  Future<void> removeCover(String directoryPath) async {
    final key = directoryCoverKey(profileId, _normalize(directoryPath));
    await _executeSafely(() async {
      await _store.writeTxn(
        () => _store.deleteById(directoryCoverCollectionId(key)),
      );
    }, 'Failed to remove directory cover');
  }

  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) async {
    final oldParent = _normalize(p.dirname(oldPath));
    final newParent = _normalize(p.dirname(newPath));
    final oldName = p.basename(oldPath);
    final newName = p.basename(newPath);

    await _executeSafely(() async {
      final cover = await _store.getByCoverKey(
        directoryCoverKey(profileId, oldParent),
      );
      if (cover == null ||
          cover.mode != DirectoryCoverMode.media ||
          cover.sourceFileName.toLowerCase() != oldName.toLowerCase()) {
        return;
      }

      await _store.writeTxn(() async {
        if (oldParent.toLowerCase() != newParent.toLowerCase()) {
          await _store.deleteById(cover.id);
          return;
        }
        cover.sourceFileName = newName;
        cover.updatedAt = DateTime.now();
        await _store.put(cover);
      });
    }, 'Failed to reconcile moved directory cover');
  }

  Future<void> removeCoverForSource(String sourcePath) async {
    final parent = _normalize(p.dirname(sourcePath));
    final name = p.basename(sourcePath);
    await _executeSafely(() async {
      final cover = await _store.getByCoverKey(
        directoryCoverKey(profileId, parent),
      );
      if (cover == null ||
          cover.mode != DirectoryCoverMode.media ||
          cover.sourceFileName.toLowerCase() != name.toLowerCase()) {
        return;
      }
      await _store.writeTxn(() => _store.deleteById(cover.id));
    }, 'Failed to remove deleted directory cover');
  }

  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) async {
    final oldRoot = _normalize(oldRootPath);
    final newRoot = _normalize(newRootPath);

    await _executeSafely(() async {
      final covers = await _store.getByProfileId(profileId);
      final affected = covers
          .where(
            (cover) =>
                _samePath(cover.directoryPath, oldRoot) ||
                p.isWithin(oldRoot, cover.directoryPath),
          )
          .toList(growable: false);
      if (affected.isEmpty) {
        return;
      }

      await _store.writeTxn(() async {
        await _store.deleteByIds(affected.map((cover) => cover.id).toList());
        for (final cover in affected) {
          final rebased = _samePath(cover.directoryPath, oldRoot)
              ? newRoot
              : p.join(newRoot, p.relative(cover.directoryPath, from: oldRoot));
          cover.directoryPath = _normalize(rebased);
          cover.coverKey = directoryCoverKey(profileId, cover.directoryPath);
          await _store.put(cover);
        }
      });
    }, 'Failed to rebase directory covers');
  }

  Future<void> removeCoversUnder(String directoryPath) async {
    final root = _normalize(directoryPath);
    await _executeSafely(() async {
      final covers = await _store.getByProfileId(profileId);
      final ids = covers
          .where(
            (cover) =>
                _samePath(cover.directoryPath, root) ||
                p.isWithin(root, cover.directoryPath),
          )
          .map((cover) => cover.id)
          .toList(growable: false);
      if (ids.isNotEmpty) {
        await _store.writeTxn(() => _store.deleteByIds(ids));
      }
    }, 'Failed to remove directory covers');
  }

  Future<void> clearCovers() async {
    await _executeSafely(() async {
      await _store.writeTxn(() => _store.deleteByProfileId(profileId));
    }, 'Failed to clear directory covers');
  }

  Future<void> _executeSafely(
    Future<void> Function() action,
    String message,
  ) async {
    try {
      await _ensureReady();
      await action();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('$message: $error'),
        stackTrace,
      );
    }
  }

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  static String _normalize(String path) => p.normalize(path);

  static bool _samePath(String first, String second) {
    return _normalize(first).toLowerCase() == _normalize(second).toLowerCase();
  }

  static DirectoryCoverCollectionStore _defaultStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarDirectoryCoverCollectionStore(database);
  }
}

/// Storage contract used by Isar in production and in-memory test stores.
abstract interface class DirectoryCoverCollectionStore {
  Future<DirectoryCoverCollection?> getByCoverKey(String coverKey);

  Future<List<DirectoryCoverCollection>> getByProfileId(String profileId);

  Future<void> put(DirectoryCoverCollection cover);

  Future<void> deleteById(Id id);

  Future<void> deleteByIds(List<Id> ids);

  Future<void> deleteByProfileId(String profileId);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarDirectoryCoverCollectionStore
    implements DirectoryCoverCollectionStore {
  IsarDirectoryCoverCollectionStore(IsarDatabase database)
    : _resolveIsar = (() => database.instance);

  final Isar Function() _resolveIsar;

  IsarCollection<DirectoryCoverCollection> get _collection =>
      _resolveIsar().collection<DirectoryCoverCollection>();

  @override
  Future<DirectoryCoverCollection?> getByCoverKey(String coverKey) {
    return _collection.get(directoryCoverCollectionId(coverKey));
  }

  @override
  Future<List<DirectoryCoverCollection>> getByProfileId(String profileId) {
    return _collection.filter().profileIdEqualTo(profileId).findAll();
  }

  @override
  Future<void> put(DirectoryCoverCollection cover) async {
    await _collection.put(cover);
  }

  @override
  Future<void> deleteById(Id id) async {
    await _collection.delete(id);
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    await _collection.deleteAll(ids);
  }

  @override
  Future<void> deleteByProfileId(String profileId) async {
    await _collection.filter().profileIdEqualTo(profileId).deleteAll();
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _resolveIsar().writeTxn(action);
  }
}
