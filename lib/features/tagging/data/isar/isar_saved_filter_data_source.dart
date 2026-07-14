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
///
/// Bound to a single profile: a filter references that profile's tag ids and
/// directory paths, so it only means anything inside it.
class IsarSavedFilterDataSource {
  IsarSavedFilterDataSource(
    this._database, {
    required this.profileId,
    SavedFilterCollectionStoreBuilder? storeBuilder,
  }) : _storeBuilder = storeBuilder ?? _defaultStoreBuilder;

  final IsarDatabase _database;

  /// The profile whose filters this data source reads and writes.
  final String profileId;

  final SavedFilterCollectionStoreBuilder _storeBuilder;

  late final SavedFilterCollectionStore _store = _storeBuilder(_database);

  static SavedFilterCollectionStore _defaultStoreBuilder(
    IsarDatabase database,
  ) {
    return IsarSavedFilterCollectionStore(database);
  }

  /// This profile's filters, oldest first.
  Future<List<SavedFilterModel>> getFilters() async {
    await _ensureReady();
    try {
      final collections = await _store.getByProfileId(profileId);
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
        await _store.put(_stamped(filter));
      });
    }, 'Failed to save filter');
  }

  Future<void> saveFilters(List<SavedFilterModel> filters) async {
    if (filters.isEmpty) {
      return;
    }
    final collections = filters.map(_stamped).toList(growable: false);

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

  /// Removes this profile's filters, leaving other profiles' alone.
  Future<void> clearFilters() async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.deleteByProfileId(profileId);
      });
    }, 'Failed to clear filters');
  }

  /// Binds [filter] to this data source's profile before it is persisted.
  SavedFilterCollection _stamped(SavedFilterModel filter) =>
      filter.copyWith(profileId: profileId).toCollection();

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
  /// Every row in the collection, across all profiles.
  ///
  /// For the migrations. Application reads want [getByProfileId].
  Future<List<SavedFilterCollection>> getAll();

  Future<List<SavedFilterCollection>> getByProfileId(String profileId);

  Future<void> put(SavedFilterCollection filter);

  Future<void> putAll(List<SavedFilterCollection> filters);

  Future<void> clear();

  Future<void> deleteById(Id id);

  /// Deletes every filter owned by [profileId].
  Future<void> deleteByProfileId(String profileId);

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
  Future<List<SavedFilterCollection>> getByProfileId(String profileId) {
    return _collection.filter().profileIdEqualTo(profileId).findAll();
  }

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
  Future<void> deleteByProfileId(String profileId) async {
    await _collection.filter().profileIdEqualTo(profileId).deleteAll();
  }

  @override
  Future<SavedFilterCollection?> getById(Id id) => _collection.get(id);

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) =>
      _isar.writeTxn(action);
}
