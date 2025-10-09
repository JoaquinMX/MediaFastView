import 'package:isar/isar.dart';

import '../../../../core/database/models/tag_record.dart';
import '../../../media_library/data/models/tag_model.dart';

/// Data source that persists tags in Isar.
class IsarTagDataSource {
  const IsarTagDataSource(this._isar);

  final Isar _isar;

  Future<List<TagModel>> getTags() async {
    final records = await _isar.tagRecords.where().sortByName().findAll();
    return records
        .map(
          (record) => TagModel(
            id: record.id,
            name: record.name,
            color: record.color,
            createdAt: record.createdAt,
          ),
        )
        .toList();
  }

  Future<void> addTag(TagModel model) async {
    await _isar.writeTxn(() async {
      await _isar.tagRecords.put(
        TagRecord(
          id: model.id,
          name: model.name,
          color: model.color,
          createdAt: model.createdAt,
        )..isarId = Isar.fastHash(model.id),
      );
    });
  }

  Future<void> updateTag(TagModel model) async {
    await addTag(model);
  }

  Future<void> removeTag(String id) async {
    await _isar.writeTxn(() async {
      final record = await _isar.tagRecords
          .where()
          .filter()
          .idEqualTo(id)
          .findFirst();
      if (record != null) {
        await _isar.tagRecords.delete(record.isarId);
      }
    });
  }
}
