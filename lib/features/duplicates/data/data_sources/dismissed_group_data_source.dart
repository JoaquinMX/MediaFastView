import 'package:isar/isar.dart';

import '../../../../core/services/isar_database.dart';
import '../isar/dismissed_duplicate_group_collection.dart';

/// Reads and writes dismissed-group signatures. An interface so the repository
/// can be unit-tested against an in-memory fake instead of Isar.
abstract interface class DismissedGroupDataSource {
  Future<Set<String>> getSignatures();

  Future<void> add(String signature);
}

/// Isar-backed [DismissedGroupDataSource].
class IsarDismissedGroupDataSource implements DismissedGroupDataSource {
  IsarDismissedGroupDataSource(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<DismissedDuplicateGroupCollection> get _collection =>
      _isar.collection<DismissedDuplicateGroupCollection>();

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  @override
  Future<Set<String>> getSignatures() async {
    await _ensureReady();
    final rows = await _collection.where().findAll();
    return rows.map((row) => row.signature).toSet();
  }

  @override
  Future<void> add(String signature) async {
    await _ensureReady();
    await _isar.writeTxn(() async {
      await _collection.put(
        DismissedDuplicateGroupCollection(
          signature: signature,
          dismissedAt: DateTime.now(),
        ),
      );
    });
  }
}
