import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/core/services/isar_database.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

import '../../../../helpers/isar_id.dart';

class _FakeIsarDatabase extends IsarDatabase {
  _FakeIsarDatabase()
      : super(
          schemas: const [],
          openIsar: _throwingOpen,
        );

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

class _InMemoryTagCollectionStore implements TagCollectionStore {
  final Map<Id, TagCollection> _data = <Id, TagCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteById(Id id) async {
    _data.remove(id);
  }

  @override
  Future<List<TagCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<TagCollection?> getByTagId(String tagId) async {
    final tag = _data[isarIdForString(tagId)];
    return tag == null ? null : _clone(tag);
  }

  @override
  Future<List<TagCollection>> getByTagIds(List<String> tagIds) async {
    return tagIds
        .map((tagId) => _data[isarIdForString(tagId)])
        .whereType<TagCollection>()
        .map(_clone)
        .toList(growable: false);
  }

  @override
  Future<void> put(TagCollection tag) async {
    _data[tag.id] = _clone(tag);
  }

  @override
  Future<void> putAll(List<TagCollection> tags) async {
    for (final tag in tags) {
      await put(tag);
    }
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() action) {
    return action();
  }

  TagCollection _clone(TagCollection tag) {
    return tag.toModel().toCollection();
  }
}

class _InMemoryDirectoryCollectionStore implements DirectoryCollectionStore {
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
    final directory = _data[isarIdForString(directoryId)];
    return directory == null ? null : _clone(directory);
  }

  @override
  Future<void> put(DirectoryCollection directory) async {
    _data[isarIdForString(directory.directoryId)] = _clone(directory);
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

class _InMemoryMediaCollectionStore implements MediaCollectionStore {
  final Map<Id, MediaCollection> _data = <Id, MediaCollection>{};

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<void> deleteByIds(List<Id> ids) async {
    for (final id in ids) {
      _data.remove(id);
    }
  }

  @override
  Future<List<MediaCollection>> getAll() async {
    return _data.values.map(_clone).toList(growable: false);
  }

  @override
  Future<MediaCollection?> getById(Id id) async {
    final media = _data[id];
    return media == null ? null : _clone(media);
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
    _data[isarIdForString(media.mediaId)] = _clone(media);
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

void main() {
  group('IsarTagDataSource', () {
    late _FakeIsarDatabase database;
    late _InMemoryTagCollectionStore tagStore;
    late _InMemoryDirectoryCollectionStore directoryStore;
    late _InMemoryMediaCollectionStore mediaStore;
    late IsarTagDataSource dataSource;

    setUp(() {
      database = _FakeIsarDatabase();
      tagStore = _InMemoryTagCollectionStore();
      directoryStore = _InMemoryDirectoryCollectionStore();
      mediaStore = _InMemoryMediaCollectionStore();
      dataSource = IsarTagDataSource(
        database,
        tagStoreBuilder: (_) => tagStore,
        directoryStoreBuilder: (_) => directoryStore,
        mediaStoreBuilder: (_) => mediaStore,
      );
    });

    TagModel _buildTag(String id) {
      return TagModel(
        id: id,
        name: 'Tag $id',
        color: 0xFF000000 + id.hashCode,
        createdAt: DateTime.utc(2024, 1, 1),
      );
    }

    DirectoryModel _buildDirectory(String id, {List<String>? tagIds}) {
      return DirectoryModel(
        id: id,
        path: '/path/$id',
        name: 'Directory $id',
        tagIds: tagIds ?? const <String>[],
        lastModified: DateTime.utc(2024, 2, 1),
      );
    }

    MediaModel _buildMedia(String id, String directoryId,
        {List<String>? tagIds}) {
      return MediaModel(
        id: id,
        path: '/media/$id',
        name: 'Media $id',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime.utc(2024, 3, 1),
        tagIds: tagIds ?? const <String>[],
        directoryId: directoryId,
      );
    }

    Future<void> _seedTags(List<TagModel> tags) async {
      await tagStore.putAll(tags.map((tag) => tag.toCollection()).toList());
    }

    test('returns empty list when no tags persisted', () async {
      final tags = await dataSource.getTags();

      expect(tags, isEmpty);
    });

    test('addTag stores tag data', () async {
      final model = _buildTag('tag-1');

      await dataSource.addTag(model);

      final tags = await dataSource.getTags();
      expect(tags, equals(<TagModel>[model]));
    });

    test('saveTags replaces existing entries', () async {
      await dataSource.saveTags(<TagModel>[_buildTag('tag-1')]);

      final replacement = _buildTag('tag-2');
      await dataSource.saveTags(<TagModel>[replacement]);

      final tags = await dataSource.getTags();
      expect(tags, equals(<TagModel>[replacement]));
    });

    test('updateTag overwrites persisted values', () async {
      final original = _buildTag('tag-1');
      await dataSource.addTag(original);

      final updated = original.copyWith(name: 'Updated');
      await dataSource.updateTag(updated);

      final tags = await dataSource.getTags();
      expect(tags, equals(<TagModel>[updated]));
    });

    test('removeTag deletes the specified tag', () async {
      final tagA = _buildTag('tag-1');
      final tagB = _buildTag('tag-2');
      await dataSource.saveTags(<TagModel>[tagA, tagB]);

      await dataSource.removeTag(tagA.id);

      final tags = await dataSource.getTags();
      expect(tags, equals(<TagModel>[tagB]));
    });

    test('getTagsForMedia resolves tag models in stored order', () async {
      final tagA = _buildTag('tag-a');
      final tagB = _buildTag('tag-b');
      final tagC = _buildTag('tag-c');
      await _seedTags(<TagModel>[tagA, tagB, tagC]);

      final media = _buildMedia(
        'media-1',
        'dir-1',
        tagIds: <String>[tagC.id, tagA.id],
      );
      await mediaStore.put(media.toCollection());

      final tags = await dataSource.getTagsForMedia(media.id);

      expect(tags, equals(<TagModel>[tagC, tagA]));
    });

    test('getTagsForDirectory resolves tag models in stored order', () async {
      final tagA = _buildTag('tag-a');
      final tagB = _buildTag('tag-b');
      await _seedTags(<TagModel>[tagA, tagB]);

      final directory = _buildDirectory(
        'dir-1',
        tagIds: <String>[tagB.id, 'missing', tagA.id],
      );
      await directoryStore.put(directory.toCollection());

      final tags = await dataSource.getTagsForDirectory(directory.id);

      expect(tags, equals(<TagModel>[tagB, tagA]));
    });

    test('returns empty list when media has no tags', () async {
      final media = _buildMedia('media-1', 'dir-1');
      await mediaStore.put(media.toCollection());

      final tags = await dataSource.getTagsForMedia(media.id);

      expect(tags, isEmpty);
    });

    test('returns empty list when directory not found', () async {
      final tags = await dataSource.getTagsForDirectory('unknown');

      expect(tags, isEmpty);
    });
  });
}
