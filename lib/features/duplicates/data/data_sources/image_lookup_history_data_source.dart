import 'package:isar/isar.dart';

import '../../../../core/services/isar_database.dart';
import '../isar/image_lookup_history_collection.dart';

/// Persistence boundary for saved image-lookup snapshots.
abstract interface class ImageLookupHistoryDataSource {
  Future<List<ImageLookupHistoryCollection>> getForProfile(String profileId);

  Future<void> put(ImageLookupHistoryCollection session);

  Future<void> delete(String sessionId);

  Future<void> clearProfile(String profileId);
}

/// Isar-backed lookup-history persistence.
class IsarImageLookupHistoryDataSource implements ImageLookupHistoryDataSource {
  IsarImageLookupHistoryDataSource(this._database);

  final IsarDatabase _database;

  IsarCollection<ImageLookupHistoryCollection> get _collection =>
      _database.instance.collection<ImageLookupHistoryCollection>();

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  @override
  Future<List<ImageLookupHistoryCollection>> getForProfile(
    String profileId,
  ) async {
    await _ensureReady();
    final rows = await _collection.where().findAll();
    final scoped = rows
        .where((row) => row.profileId == profileId)
        .toList(growable: false);
    scoped.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return scoped;
  }

  @override
  Future<void> put(ImageLookupHistoryCollection session) async {
    await _ensureReady();
    await _database.instance.writeTxn(() => _collection.put(session));
  }

  @override
  Future<void> delete(String sessionId) async {
    await _ensureReady();
    await _database.instance.writeTxn(
      () => _collection.delete(imageLookupHistoryCollectionId(sessionId)),
    );
  }

  @override
  Future<void> clearProfile(String profileId) async {
    final rows = await getForProfile(profileId);
    if (rows.isEmpty) {
      return;
    }
    await _database.instance.writeTxn(
      () => _collection.deleteAll(rows.map((row) => row.id).toList()),
    );
  }
}
