import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
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
/// This data source mirrors the behaviour expected by the repositories while
/// running entirely on top of Isar collections. All operations run inside
/// transactions to guarantee
/// consistency when multiple models are modified at once.
class IsarDirectoryDataSource {
  IsarDirectoryDataSource(
    this._database, {
    DirectoryCollectionStoreBuilder? directoryStoreBuilder,
  }) : _directoryStoreBuilder =
            directoryStoreBuilder ?? _defaultDirectoryStoreBuilder;

  final IsarDatabase _database;
  final DirectoryCollectionStoreBuilder _directoryStoreBuilder;

  late final DirectoryCollectionStore _store = _directoryStoreBuilder(_database);

  /// Retrieves every persisted directory.
  Future<List<DirectoryModel>> getDirectories() async {
    await _ensureReady();
    try {
      final collections = await _store.getAll();
      return collections.map((collection) => collection.toModel()).toList(
            growable: false,
          );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load directories: $error'),
        stackTrace,
      );
    }
  }

  /// Replaces all persisted directories with [directories].
  Future<void> saveDirectories(List<DirectoryModel> directories) async {
    final collections =
        directories.map((directory) => directory.toCollection()).toList();
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.clear();
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
        await _store.deleteById(Isar.fastHash(id));
      });
    }, 'Failed to remove directory');
  }

  /// Updates the persisted representation of [updatedDirectory].
  Future<void> updateDirectory(DirectoryModel updatedDirectory) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.put(updatedDirectory.toCollection());
      });
    }, 'Failed to update directory');
  }

  /// Removes all directories from persistence.
  Future<void> clearDirectories() async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.clear();
      });
    }, 'Failed to clear directories');
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
}

/// Contract abstracting access to persisted [DirectoryCollection] records.
///
/// Defining this contract allows the production implementation to delegate to
/// Isar while tests can provide an in-memory variant without touching disk or
/// depending on code generation.
abstract interface class DirectoryCollectionStore {
  Future<List<DirectoryCollection>> getAll();

  Future<void> putAll(List<DirectoryCollection> directories);

  Future<void> put(DirectoryCollection directory);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<DirectoryCollection?> getByDirectoryId(String directoryId);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarDirectoryCollectionStore implements DirectoryCollectionStore {
  IsarDirectoryCollectionStore(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<DirectoryCollection> get _collection =>
      _isar.collection<DirectoryCollection>();

  @override
  Future<List<DirectoryCollection>> getAll() {
    return _collection
        .where()
        .addWhereClause(const IdWhereClause.any())
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
    return _collection.get(Isar.fastHash(directoryId));
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return _isar.writeTxn(action);
  }
}
