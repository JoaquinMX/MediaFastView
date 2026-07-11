import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';


/// An [IsarDatabase] that reports itself open but is never actually touched —
/// the in-memory stores below stand in for every collection.
class FakeIsarDatabase extends IsarDatabase {
  FakeIsarDatabase() : super(schemas: const [], openIsar: _throwingOpen);

  static Future<Isar> _throwingOpen(
    List<CollectionSchema<dynamic>> schemas, {
    String? directory,
    String? name,
  }) async {
    throw UnimplementedError();
  }

  @override
  bool get isOpen => true;

  @override
  Isar get instance => throw UnimplementedError();
}

class InMemoryDirectoryCollectionStore implements DirectoryCollectionStore {
  final Map<Id, DirectoryCollection> _data = <Id, DirectoryCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    _data.remove(id);
  }

  @override
  Future<List<DirectoryCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<DirectoryCollection?> getByDirectoryId(String directoryId) async {
    for (final directory in _data.values) {
      if (directory.directoryId == directoryId) {
        return _clone(directory);
      }
    }
    return null;
  }

  @override
  Future<void> put(DirectoryCollection directory) async {
    // Key by the collection's own Isar id getter rather than recomputing it, so
    // `deleteById` lines up with whatever id production hands us.
    _data[directory.id] = _clone(directory);
  }

  @override
  Future<void> putAll(List<DirectoryCollection> directories) async {
    for (final directory in directories) {
      await put(directory);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  DirectoryCollection _clone(DirectoryCollection directory) {
    return directory.toModel().toCollection();
  }
}

class InMemoryMediaCollectionStore implements MediaCollectionStore {
  final Map<String, MediaCollection> _data = <String, MediaCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    // Production `MediaCollection.id` is computed via
    // `mediaCollectionIdFromMediaId(mediaId)`, not `isarIdForString(mediaId)`.
    // Use the same function so this fake matches what production hands us.
    _data.removeWhere(
      (key, _) => ids.contains(mediaCollectionIdFromMediaId(key)),
    );
  }

  @override
  Future<List<MediaCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<MediaCollection?> getById(Id id) async {
    // Match production: id is `mediaCollectionIdFromMediaId(mediaId)`.
    for (final entry in _data.entries) {
      if (mediaCollectionIdFromMediaId(entry.key) == id) {
        return _clone(entry.value);
      }
    }
    return null;
  }

  @override
  Future<MediaCollection?> getByMediaId(String mediaId) async {
    final media = _data[mediaId];
    return media != null ? _clone(media) : null;
  }

  @override
  Future<MediaCollection?> getByPath(String path) async {
    for (final media in _data.values) {
      if (media.path.toLowerCase() == path.toLowerCase()) {
        return _clone(media);
      }
    }
    return null;
  }

  @override
  Future<List<MediaCollection>> getByDirectoryId(String directoryId) async {
    return _data.values
        .where((media) => media.directoryId == directoryId)
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(MediaCollection media) async {
    // `path` is a unique index with `replace: true`, so a write evicts whatever
    // other record held that path. Reproducing it here is what lets tests catch
    // a miscomputed destination path silently destroying a row.
    _data.removeWhere(
      (mediaId, existing) =>
          mediaId != media.mediaId &&
          existing.path.toLowerCase() == media.path.toLowerCase(),
    );
    _data[media.mediaId] = _clone(media);
  }

  @override
  Future<void> putAll(List<MediaCollection> media) async {
    for (final item in media) {
      await put(item);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  MediaCollection _clone(MediaCollection media) {
    final clone = media.toModel().toCollection();
    clone.directory.value = media.directory.value;
    return clone;
  }
}
