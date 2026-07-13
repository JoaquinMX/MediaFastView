import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../models/saved_filter_model.dart';
import 'saved_filter_collection.dart';

/// Signature for building a [SavedFilterCollectionStore] bound to an
/// [IsarDatabase].
typedef SavedFilterCollectionStoreBuilder = SavedFilterCollectionStore Function(
  IsarDatabase database,
);

/// Provides CRUD access to [SavedFilterCollection] entries.
class IsarSavedFilterDataSource {
  IsarSavedFilterDataSource(
    this._database, {
    SavedFilterCollectionStoreBuilder? storeBuilder,
  }) : _storeBuilder = storeBuilder ?? _defaultStoreBuilder;

  final IsarDatabase _database;
  final SavedFilterCollectionStoreBuilder _storeBuilder;

  late final SavedFilterCollectionStore _store = _storeBuilder(_database);

  static SavedFilterCollectionStore _defaultStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarSavedFilterCollectionStore(database);
  }

  /// Every persisted filter, oldest first.
  Future<List<SavedFilterModel>> getFilters() async {
    await _ensureReady();
    try {
      final collections = await _store.getAll();
      collections.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load saved filters: $error'),
        stackTrace,
      );
    }
  }

  /// Creates or replaces [filter], keyed on its id.
  Future<void> saveFilter(SavedFilterModel filter) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.put(filter.toCollection());
      });
    }, 'Failed to save filter');
  }

  Future<void> saveFilters(List<SavedFilterModel> filters) async {
    if (filters.isEmpty) {
      return;
    }
    final collections =
        filters.map((filter) => filter.toCollection()).toList(growable: false);

    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.putAll(collections);
      });
    }, 'Failed to save filters');
  }

  Future<void> removeFilter(String id) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.deleteById(savedFilterCollectionId(id));
      });
    }, 'Failed to remove filter');
  }

  Future<void> clearFilters() async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.clear();
      });
    }, 'Failed to clear filters');
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
}

/// Contract abstracting access to persisted [SavedFilterCollection] records.
abstract interface class SavedFilterCollectionStore {
  Future<List<SavedFilterCollection>> getAll();

  Future<void> put(SavedFilterCollection filter);

  Future<void> putAll(List<SavedFilterCollection> filters);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<SavedFilterCollection?> getById(Id id);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarSavedFilterCollectionStore implements SavedFilterCollectionStore {
  IsarSavedFilterCollectionStore(IsarDatabase database)
    : _resolveIsar = (() => database.instance);

  /// Binds to an already-open [Isar] directly, matching the other stores.
  IsarSavedFilterCollectionStore.forIsar(Isar isar)
    : _resolveIsar = (() => isar);

  final Isar Function() _resolveIsar;

  Isar get _isar => _resolveIsar();

  IsarCollection<SavedFilterCollection> get _collection =>
      _isar.collection<SavedFilterCollection>();

  @override
  Future<List<SavedFilterCollection>> getAll() =>
      _collection.where().findAll();

  @override
  Future<void> put(SavedFilterCollection filter) async {
    await _collection.put(filter);
  }

  @override
  Future<void> putAll(List<SavedFilterCollection> filters) async {
    await _collection.putAll(filters);
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
  Future<SavedFilterCollection?> getById(Id id) => _collection.get(id);

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) =>
      _isar.writeTxn(action);
}
