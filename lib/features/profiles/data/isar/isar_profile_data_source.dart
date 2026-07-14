import 'package:isar/isar.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/isar_database.dart';
import '../models/profile_model.dart';
import 'profile_collection.dart';

/// Signature for building a [ProfileCollectionStore] bound to an [IsarDatabase].
typedef ProfileCollectionStoreBuilder = ProfileCollectionStore Function(
  IsarDatabase database,
);

/// Provides CRUD access to [ProfileCollection] entries.
///
/// Unlike the other data sources this one is not bound to a profile — it is the
/// one that hands them out.
class IsarProfileDataSource {
  IsarProfileDataSource(
    this._database, {
    ProfileCollectionStoreBuilder? storeBuilder,
  }) : _storeBuilder = storeBuilder ?? _defaultStoreBuilder;

  final IsarDatabase _database;
  final ProfileCollectionStoreBuilder _storeBuilder;

  late final ProfileCollectionStore _store = _storeBuilder(_database);

  static ProfileCollectionStore _defaultStoreBuilder(IsarDatabase database) {
    return IsarProfileCollectionStore(database);
  }

  /// Every profile, ordered as the switcher shows them.
  Future<List<ProfileModel>> getProfiles() async {
    await _ensureReady();
    try {
      final collections = await _store.getAll();
      collections.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
      });
      return collections
          .map((collection) => collection.toModel())
          .toList(growable: false);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PersistenceError('Failed to load profiles: $error'),
        stackTrace,
      );
    }
  }

  /// Creates or replaces [profile], keyed on its id.
  Future<void> saveProfile(ProfileModel profile) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.put(profile.toCollection());
      });
    }, 'Failed to save profile');
  }

  /// Removes the profile identified by [id].
  ///
  /// Only drops the profile row. The data it owned — directories, tags,
  /// favorites, filters — is unwound by `DeleteProfileUseCase`, which knows the
  /// rules for what to keep.
  Future<void> removeProfile(String id) async {
    await _executeSafely(() async {
      await _store.writeTxn(() async {
        await _store.deleteById(profileCollectionId(id));
      });
    }, 'Failed to remove profile');
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

/// Contract abstracting access to persisted [ProfileCollection] records.
abstract interface class ProfileCollectionStore {
  Future<List<ProfileCollection>> getAll();

  Future<void> put(ProfileCollection profile);

  Future<void> putAll(List<ProfileCollection> profiles);

  Future<void> clear();

  Future<void> deleteById(Id id);

  Future<T> writeTxn<T>(Future<T> Function() action);
}

class IsarProfileCollectionStore implements ProfileCollectionStore {
  IsarProfileCollectionStore(IsarDatabase database)
      : _resolveIsar = (() => database.instance);

  /// Binds to an already-open [Isar] directly.
  ///
  /// For the profile migration, which runs inside `IsarDatabase.open()` before
  /// the instance is published — so `database.instance` would still throw.
  IsarProfileCollectionStore.forIsar(Isar isar) : _resolveIsar = (() => isar);

  final Isar Function() _resolveIsar;

  Isar get _isar => _resolveIsar();

  IsarCollection<ProfileCollection> get _collection =>
      _isar.collection<ProfileCollection>();

  @override
  Future<List<ProfileCollection>> getAll() => _collection.where().findAll();

  @override
  Future<void> put(ProfileCollection profile) async {
    await _collection.put(profile);
  }

  @override
  Future<void> putAll(List<ProfileCollection> profiles) async {
    await _collection.putAll(profiles);
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
  Future<T> writeTxn<T>(Future<T> Function() action) => _isar.writeTxn(action);
}
