import 'package:isar/isar.dart';

import '../../../../core/database/models/directory_record.dart';
import '../models/directory_model.dart';

/// Data source that persists directories inside Isar.
class IsarDirectoryDataSource {
  const IsarDirectoryDataSource(this._isar);

  final Isar _isar;

  Future<List<DirectoryModel>> getDirectories() async {
    final records = await _isar.directoryRecords.where().findAll();
    return records.map(_mapFromRecord).toList();
  }

  Future<void> addDirectory(DirectoryModel directory) async {
    await _isar.writeTxn(() async {
      await _isar.directoryRecords.put(_mapToRecord(directory));
    });
  }

  Future<void> updateDirectory(DirectoryModel directory) async {
    await addDirectory(directory);
  }

  Future<void> removeDirectory(String id) async {
    await _isar.writeTxn(() async {
      final record = await _isar.directoryRecords
          .where()
          .filter()
          .idEqualTo(id)
          .findFirst();
      if (record != null) {
        await _isar.directoryRecords.delete(record.isarId);
      }
    });
  }

  Future<void> clearDirectories() async {
    await _isar.writeTxn(() async {
      await _isar.directoryRecords.clear();
    });
  }

  Future<void> putAll(List<DirectoryModel> directories) async {
    await _isar.writeTxn(() async {
      await _isar.directoryRecords.putAll(
        directories.map(_mapToRecord).toList(),
      );
    });
  }

  DirectoryModel _mapFromRecord(DirectoryRecord record) {
    return DirectoryModel(
      id: record.id,
      path: record.path,
      name: record.name,
      thumbnailPath: record.thumbnailPath,
      tagIds: List<String>.from(record.tagIds),
      lastModified: record.lastModified,
      bookmarkData: record.bookmarkData,
    );
  }

  DirectoryRecord _mapToRecord(DirectoryModel model) {
    return DirectoryRecord(
      id: model.id,
      path: model.path,
      name: model.name,
      thumbnailPath: model.thumbnailPath,
      tagIds: List<String>.from(model.tagIds),
      lastModified: model.lastModified,
      bookmarkData: model.bookmarkData,
    )
      ..isarId = Isar.fastHash(model.id);
  }
}
