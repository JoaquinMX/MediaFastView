import 'package:isar/isar.dart';

import '../../../../core/services/isar_database.dart';
import '../../domain/entities/perceptual_hash.dart';
import '../isar/perceptual_hash_collection.dart';

/// Reads and writes cached perceptual hashes. An interface so the repository can
/// be unit-tested against an in-memory fake instead of Isar.
abstract interface class PerceptualHashDataSource {
  /// The cached hashes for [mediaIds], keyed by media id. Missing ids are simply
  /// absent from the map.
  Future<Map<String, PerceptualHash>> getByMediaIds(Iterable<String> mediaIds);

  /// Upserts [hashes], replacing any existing entry for the same media id.
  Future<void> putAll(List<PerceptualHash> hashes);
}

/// Isar-backed [PerceptualHashDataSource].
class IsarPerceptualHashDataSource implements PerceptualHashDataSource {
  IsarPerceptualHashDataSource(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<PerceptualHashCollection> get _collection =>
      _isar.collection<PerceptualHashCollection>();

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  @override
  Future<Map<String, PerceptualHash>> getByMediaIds(
    Iterable<String> mediaIds,
  ) async {
    await _ensureReady();
    final ids = mediaIds
        .map(perceptualHashCollectionId)
        .toList(growable: false);
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _collection.getAll(ids);
    final result = <String, PerceptualHash>{};
    for (final row in rows) {
      if (row != null) {
        result[row.mediaId] = row.toDomain();
      }
    }
    return result;
  }

  @override
  Future<void> putAll(List<PerceptualHash> hashes) async {
    if (hashes.isEmpty) {
      return;
    }
    await _ensureReady();
    final collections = hashes
        .map((hash) => hash.toCollection())
        .toList(growable: false);
    await _isar.writeTxn(() async {
      await _collection.putAll(collections);
    });
  }
}
