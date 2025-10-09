import 'package:isar/isar.dart';

import '../../../../core/database/models/favorite_record.dart';
import '../models/favorite_model.dart';

/// Data source that persists favorites in Isar.
class IsarFavoritesDataSource {
  const IsarFavoritesDataSource(this._isar);

  final Isar _isar;

  Future<List<FavoriteModel>> getFavorites() async {
    final records = await _isar.favoriteRecords.where().findAll();
    return records
        .map(
          (record) => FavoriteModel(
            mediaId: record.mediaId,
            addedAt: record.addedAt,
          ),
        )
        .toList();
  }

  Future<void> addFavorite(FavoriteModel favorite) async {
    await _isar.writeTxn(() async {
      await _isar.favoriteRecords.put(
        FavoriteRecord(
          mediaId: favorite.mediaId,
          addedAt: favorite.addedAt,
        )..isarId = Isar.fastHash(favorite.mediaId),
      );
    });
  }

  Future<void> removeFavorite(String mediaId) async {
    await _isar.writeTxn(() async {
      final record = await _isar.favoriteRecords
          .where()
          .filter()
          .mediaIdEqualTo(mediaId)
          .findFirst();
      if (record != null) {
        await _isar.favoriteRecords.delete(record.isarId);
      }
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.favoriteRecords.clear();
    });
  }
}
