import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

import '../../../../helpers/in_memory_isar_stores.dart';

const String _profile = 'profile-1';
const String _otherProfile = 'profile-2';

void main() {
  group('IsarDirectoryDataSource', () {
    late FakeIsarDatabase database;
    late InMemoryDirectoryCollectionStore store;
    late InMemoryTagCollectionStore tagStore;
    late IsarDirectoryDataSource dataSource;

    /// Registers a tag so the data source can resolve which profile owns it.
    ///
    /// Tag assignments are ids on the directory row; the owner lives on the tag
    /// itself, so a tag that does not exist cannot be attributed to anyone and is
    /// dropped on read.
    Future<void> seedTag(String tagId, {String profileId = _profile}) {
      return tagStore.put(
        TagModel(
          id: tagId,
          profileId: profileId,
          name: tagId,
          color: 0xFF000000,
          createdAt: DateTime.utc(2024, 1, 1),
        ).toCollection(),
      );
    }

    setUp(() async {
      database = FakeIsarDatabase();
      store = InMemoryDirectoryCollectionStore();
      tagStore = InMemoryTagCollectionStore();
      dataSource = IsarDirectoryDataSource(
        database,
        profileId: _profile,
        directoryStoreBuilder: (_) => store,
        tagStoreBuilder: (_) => tagStore,
      );

      for (final tagId in <String>['tag-dir-1', 'tag-dir-2', 'a', 'b']) {
        await seedTag(tagId);
      }
    });

    DirectoryModel buildDirectory({
      required String id,
      String? name,
      List<String>? profileIds,
    }) {
      return DirectoryModel(
        id: id,
        path: '/path/$id',
        name: name ?? 'Directory $id',
        tagIds: <String>['tag-$id'],
        profileIds: profileIds ?? const <String>[_profile],
        lastModified: DateTime.utc(2024, 1, 1),
        bookmarkData: 'bookmark-$id',
      );
    }

    test('returns empty list when no directories persisted', () async {
      final directories = await dataSource.getDirectories();

      expect(directories, isEmpty);
    });

    test('addDirectory stores directory data', () async {
      final model = buildDirectory(id: 'dir-1');

      await dataSource.addDirectory(model);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[model]));
    });

    test('getDirectories only returns this profile\'s directories', () async {
      await dataSource.addDirectory(buildDirectory(id: 'dir-1'));
      await dataSource.addDirectory(
        buildDirectory(id: 'dir-2', profileIds: const <String>[_otherProfile]),
      );

      final directories = await dataSource.getDirectories();

      expect(
        directories.map((directory) => directory.id),
        equals(<String>['dir-1']),
      );
    });

    test('getDirectoryById retrieves a stored directory', () async {
      final model = buildDirectory(id: 'dir-1');
      await dataSource.addDirectory(model);

      final result = await dataSource.getDirectoryById('dir-1');

      expect(result, equals(model));
    });

    test('getDirectoryById returns null when directory missing', () async {
      final result = await dataSource.getDirectoryById('unknown');

      expect(result, isNull);
    });

    test('getDirectoryByPathUnscoped finds another profile\'s row', () async {
      await dataSource.addDirectory(
        buildDirectory(id: 'dir-2', profileIds: const <String>[_otherProfile]),
      );

      final result = await dataSource.getDirectoryByPathUnscoped('/path/dir-2');

      expect(result, isNotNull);
      expect(result!.profileIds, equals(<String>[_otherProfile]));
    });

    test('saveDirectories replaces existing entries', () async {
      final original = buildDirectory(id: 'dir-1', name: 'Original');
      await dataSource.addDirectory(original);
      final replacement = buildDirectory(id: 'dir-2', name: 'Replacement');

      await dataSource.saveDirectories(<DirectoryModel>[replacement]);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[replacement]));
    });

    test('removeDirectory deletes the specified directory', () async {
      final modelA = buildDirectory(id: 'dir-1');
      final modelB = buildDirectory(id: 'dir-2');
      await dataSource.saveDirectories(<DirectoryModel>[modelA, modelB]);

      await dataSource.removeDirectory(modelA.id);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[modelB]));
    });

    test('updateDirectory overwrites persisted values', () async {
      final original = buildDirectory(id: 'dir-1', name: 'Original');
      await dataSource.addDirectory(original);

      final updated = original.copyWith(name: 'Updated');
      await dataSource.updateDirectory(updated);

      final directories = await dataSource.getDirectories();
      expect(directories, equals(<DirectoryModel>[updated]));
    });

    test('updateDirectoryTagsBatch updates only matching directories', () async {
      final first = buildDirectory(id: 'dir-1', name: 'First');
      final second = buildDirectory(id: 'dir-2', name: 'Second');
      await dataSource.saveDirectories(<DirectoryModel>[first, second]);

      final result = await dataSource.updateDirectoryTagsBatch(
        <String, List<String>>{
          'dir-1': <String>['a', 'b'],
          'missing': const <String>['c'],
        },
      );

      final directories = await dataSource.getDirectories();
      final updated = directories.firstWhere((dir) => dir.id == 'dir-1');
      final untouched = directories.firstWhere((dir) => dir.id == 'dir-2');

      expect(updated.tagIds, equals(<String>['a', 'b']));
      expect(untouched.tagIds, equals(second.tagIds));
      expect(result.successfulIds, equals(<String>['dir-1']));
      expect(result.failureReasons.keys, contains('missing'));
    });

    test('clearDirectories removes all entries', () async {
      await dataSource.saveDirectories(
        <DirectoryModel>[
          buildDirectory(id: 'dir-1'),
          buildDirectory(id: 'dir-2'),
        ],
      );

      await dataSource.clearDirectories();

      final directories = await dataSource.getDirectories();
      expect(directories, isEmpty);
    });

    group('sharing a directory between profiles', () {
      const String foreignTag = 'tag-owned-by-other-profile';

      setUp(() async {
        await seedTag(foreignTag, profileId: _otherProfile);
      });

      test('reads hide the other profile\'s tags', () async {
        await store.put(
          buildDirectory(
            id: 'shared',
            profileIds: const <String>[_profile, _otherProfile],
          ).copyWith(tagIds: <String>['a', foreignTag]).toCollection(),
        );

        final directories = await dataSource.getDirectories();

        expect(directories.single.tagIds, equals(<String>['a']));
      });

      test('writing tags preserves the other profile\'s tags', () async {
        await store.put(
          buildDirectory(
            id: 'shared',
            profileIds: const <String>[_profile, _otherProfile],
          ).copyWith(tagIds: <String>['a', foreignTag]).toCollection(),
        );

        await dataSource.updateDirectoryTagsBatch(
          <String, List<String>>{'shared': <String>['b']},
        );

        final persisted = await store.getByDirectoryId('shared');
        expect(persisted!.tagIds, containsAll(<String>[foreignTag, 'b']));
        expect(persisted.tagIds, isNot(contains('a')));
      });

      test('clearing this profile\'s tags leaves the other profile\'s', () async {
        await store.put(
          buildDirectory(
            id: 'shared',
            profileIds: const <String>[_profile, _otherProfile],
          ).copyWith(tagIds: <String>['a', foreignTag]).toCollection(),
        );

        await dataSource.updateDirectoryTagsBatch(
          <String, List<String>>{'shared': const <String>[]},
        );

        final persisted = await store.getByDirectoryId('shared');
        expect(persisted!.tagIds, equals(<String>[foreignTag]));
      });

      test('clearDirectories keeps a directory another profile still owns',
          () async {
        await store.put(
          buildDirectory(
            id: 'shared',
            profileIds: const <String>[_profile, _otherProfile],
          ).toCollection(),
        );
        await store.put(
          buildDirectory(id: 'mine', profileIds: const <String>[_profile])
              .toCollection(),
        );

        await dataSource.clearDirectories();

        final survivor = await store.getByDirectoryId('shared');
        expect(survivor, isNotNull);
        expect(survivor!.profileIds, equals(<String>[_otherProfile]));
        expect(survivor.bookmarkData, equals('bookmark-shared'));
        expect(await store.getByDirectoryId('mine'), isNull);
      });
    });
  });
}
