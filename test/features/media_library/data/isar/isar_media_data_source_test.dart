import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../../helpers/in_memory_isar_stores.dart';

void main() {
  group('IsarMediaDataSource', () {
    late FakeIsarDatabase database;
    late InMemoryDirectoryCollectionStore directoryStore;
    late InMemoryMediaCollectionStore mediaStore;
    late IsarMediaDataSource dataSource;

    setUp(() {
      database = FakeIsarDatabase();
      directoryStore = InMemoryDirectoryCollectionStore();
      mediaStore = InMemoryMediaCollectionStore();
      dataSource = IsarMediaDataSource(
        database,
        mediaStoreBuilder: (_) => mediaStore,
        directoryStoreBuilder: (_) => directoryStore,
      );
    });

    DirectoryModel _buildDirectory(String id) {
      return DirectoryModel(
        id: id,
        path: '/path/$id',
        name: 'Directory $id',
        lastModified: DateTime.utc(2024, 1, 1),
      );
    }

    MediaModel _buildMedia({
      required String id,
      required String directoryId,
      List<String> tagIds = const <String>[],
    }) {
      return MediaModel(
        id: id,
        path: '/media/$id',
        name: 'Media $id',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime.utc(2024, 2, 1),
        tagIds: tagIds,
        directoryId: directoryId,
      );
    }

    Future<void> _seedDirectories(List<DirectoryModel> directories) async {
      for (final directory in directories) {
        await directoryStore.put(directory.toCollection());
      }
    }

    test('returns empty list when no media persisted', () async {
      final media = await dataSource.getMedia();

      expect(media, isEmpty);
    });

    test('saveMedia replaces stored media', () async {
      await _seedDirectories(<DirectoryModel>[_buildDirectory('dir-1')]);
      final initial = _buildMedia(id: 'media-1', directoryId: 'dir-1');
      await dataSource.saveMedia(<MediaModel>[initial]);

      final replacement = _buildMedia(id: 'media-2', directoryId: 'dir-1');
      await dataSource.saveMedia(<MediaModel>[replacement]);

      final media = await dataSource.getMedia();
      expect(media, equals(<MediaModel>[replacement]));
    });

    test('upsertMedia inserts and updates media entries', () async {
      await _seedDirectories(<DirectoryModel>[_buildDirectory('dir-1')]);
      final original = _buildMedia(id: 'media-1', directoryId: 'dir-1');
      await dataSource.saveMedia(<MediaModel>[original]);

      final updated = original.copyWith(name: 'Updated Media');
      final newItem = _buildMedia(id: 'media-2', directoryId: 'dir-1');
      await dataSource.upsertMedia(<MediaModel>[updated, newItem]);

      final media = await dataSource.getMedia();
      expect(media, hasLength(2));
      expect(media, containsAll(<MediaModel>[updated, newItem]));
    });

    test('getMediaForDirectory filters by directory', () async {
      await _seedDirectories(<DirectoryModel>[
        _buildDirectory('dir-1'),
        _buildDirectory('dir-2'),
      ]);
      await dataSource.saveMedia(<MediaModel>[
        _buildMedia(id: 'media-1', directoryId: 'dir-1'),
        _buildMedia(id: 'media-2', directoryId: 'dir-2'),
      ]);

      final media = await dataSource.getMediaForDirectory('dir-1');
      expect(media, equals(<MediaModel>[_buildMedia(id: 'media-1', directoryId: 'dir-1')]));
    });

    test('addMedia appends new entries', () async {
      await _seedDirectories(<DirectoryModel>[
        _buildDirectory('dir-1'),
        _buildDirectory('dir-2'),
      ]);
      await dataSource.saveMedia(<MediaModel>[
        _buildMedia(id: 'media-1', directoryId: 'dir-1'),
      ]);

      await dataSource.addMedia(<MediaModel>[
        _buildMedia(id: 'media-2', directoryId: 'dir-2'),
      ]);

      final media = await dataSource.getMedia();
      expect(media, hasLength(2));
    });

    test('updateMediaTags overwrites tag assignments', () async {
      await _seedDirectories(<DirectoryModel>[_buildDirectory('dir-1')]);
      final mediaModel = _buildMedia(
        id: 'media-1',
        directoryId: 'dir-1',
        tagIds: const <String>['old'],
      );
      await dataSource.saveMedia(<MediaModel>[mediaModel]);

      await dataSource.updateMediaTags('media-1', <String>['new', 'tags']);

      final media = await dataSource.getMedia();
      expect(media.single.tagIds, equals(<String>['new', 'tags']));
    });

    test('updateMediaTagsBatch updates only targeted entries', () async {
      await _seedDirectories(<DirectoryModel>[_buildDirectory('dir-1')]);
      final mediaModels = <MediaModel>[
        _buildMedia(
          id: 'media-1',
          directoryId: 'dir-1',
          tagIds: const <String>['keep'],
        ),
        _buildMedia(
          id: 'media-2',
          directoryId: 'dir-1',
          tagIds: const <String>['original'],
        ),
      ];
      await dataSource.saveMedia(mediaModels);

      final result = await dataSource.updateMediaTagsBatch(<String, List<String>>{
        'media-1': <String>['new'],
        'missing-media': const <String>['ignored'],
      });

      final media = await dataSource.getMedia();
      final updated = media.firstWhere((m) => m.id == 'media-1');
      final untouched = media.firstWhere((m) => m.id == 'media-2');

      expect(updated.tagIds, equals(<String>['new']));
      expect(untouched.tagIds, equals(<String>['original']));
      expect(result.successfulIds, equals(<String>['media-1']));
      expect(result.failureReasons.keys, contains('missing-media'));
    });

    test('removeMediaForDirectory deletes matching entries', () async {
      await _seedDirectories(<DirectoryModel>[
        _buildDirectory('dir-1'),
        _buildDirectory('dir-2'),
      ]);
      await dataSource.saveMedia(<MediaModel>[
        _buildMedia(id: 'media-1', directoryId: 'dir-1'),
        _buildMedia(id: 'media-2', directoryId: 'dir-2'),
      ]);

      await dataSource.removeMediaForDirectory('dir-1');

      final media = await dataSource.getMedia();
      expect(media, equals(<MediaModel>[_buildMedia(id: 'media-2', directoryId: 'dir-2')]));
    });

    test('migrateDirectoryId updates legacy references', () async {
      await _seedDirectories(<DirectoryModel>[
        _buildDirectory('legacy'),
        _buildDirectory('stable'),
      ]);
      await dataSource.saveMedia(<MediaModel>[
        _buildMedia(id: 'media-1', directoryId: 'legacy'),
      ]);

      await dataSource.migrateDirectoryId('legacy', 'stable');

      final media = await dataSource.getMedia();
      expect(media.single.directoryId, equals('stable'));
    });

    test('migrateDirectoryId is no-op when ids match', () async {
      await _seedDirectories(<DirectoryModel>[_buildDirectory('dir-1')]);
      await dataSource.saveMedia(<MediaModel>[
        _buildMedia(id: 'media-1', directoryId: 'dir-1'),
      ]);

      await dataSource.migrateDirectoryId('dir-1', 'dir-1');

      final media = await dataSource.getMedia();
      expect(media.single.directoryId, equals('dir-1'));
    });
  });
}
