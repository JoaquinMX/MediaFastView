import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/isar_key_migration.dart';
import 'package:media_fast_view/core/services/isar_profile_migration.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/profiles/data/isar/profile_collection.dart';
import 'package:media_fast_view/features/profiles/data/models/profile_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/saved_filter_collection.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';
import 'package:media_fast_view/features/tagging/data/models/saved_filter_model.dart';

import '../../helpers/in_memory_isar_stores.dart';
import '../../helpers/isar_id.dart';

/// A directory row as a pre-profiles build wrote it: no profile.
DirectoryCollection _directory(String id, {List<String>? tagIds}) {
  return DirectoryModel(
    id: id,
    path: '/library/$id',
    name: id,
    tagIds: tagIds ?? const <String>[],
    lastModified: DateTime(2024, 1, 1),
    bookmarkData: 'bookmark-$id',
    lastScanAt: DateTime(2024, 2, 1),
  ).toCollection();
}

TagCollection _tag(String id) {
  return TagModel(
    id: id,
    name: id,
    color: 0xFF2196F3,
    createdAt: DateTime(2024, 1, 1),
  ).toCollection();
}

FavoriteCollection _favorite(String itemId, {FavoriteItemType? type}) {
  return FavoriteModel(
    itemId: itemId,
    itemType: type ?? FavoriteItemType.media,
    addedAt: DateTime(2024, 1, 1),
  ).toCollection();
}

SavedFilterCollection _filter(String id) {
  return SavedFilterModel(
    id: id,
    name: id,
    requiredTagIds: const <String>['tag-a'],
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  ).toCollection();
}

void main() {
  late InMemoryProfileCollectionStore profiles;
  late InMemoryDirectoryCollectionStore directories;
  late InMemoryTagCollectionStore tags;
  late InMemoryFavoriteCollectionStore favorites;
  late InMemorySavedFilterCollectionStore filters;
  late int backUpCount;

  setUp(() {
    profiles = InMemoryProfileCollectionStore();
    directories = InMemoryDirectoryCollectionStore();
    tags = InMemoryTagCollectionStore();
    favorites = InMemoryFavoriteCollectionStore();
    filters = InMemorySavedFilterCollectionStore();
    backUpCount = 0;
  });

  Future<IsarProfileMigrationReport> migrate() {
    return const IsarProfileMigration().runOnStores(
      profiles: profiles,
      directories: directories,
      tags: tags,
      favorites: favorites,
      filters: filters,
      backUp: () async => backUpCount += 1,
    );
  }

  Future<void> seedPreProfileLibrary() async {
    await directories.put(_directory('photos', tagIds: <String>['tag-a']));
    await directories.put(_directory('trips'));
    await tags.put(_tag('tag-a'));
    await tags.put(_tag('tag-b'));
    await favorites.put(_favorite('media-1'));
    await favorites.put(
      _favorite('dir-1', type: FavoriteItemType.directory),
    );
    await filters.put(_filter('filter-1'));
  }

  group('a pre-profiles library', () {
    test('is adopted into a single Default profile', () async {
      await seedPreProfileLibrary();

      final report = await migrate();

      final created = await profiles.getAll();
      expect(created, hasLength(1));
      expect(created.single.name, defaultProfileName);
      expect(report.profileId, created.single.profileId);

      expect(report.directoriesStamped, 2);
      expect(report.tagsStamped, 2);
      expect(report.favoritesStamped, 2);
      expect(report.filtersStamped, 1);
    });

    test('stamps every collection with the new profile', () async {
      await seedPreProfileLibrary();

      final profileId = (await migrate()).profileId!;

      expect(
        (await directories.getByProfileId(profileId)).map((d) => d.directoryId),
        containsAll(<String>['photos', 'trips']),
      );
      expect((await tags.getByProfileId(profileId)), hasLength(2));
      expect((await favorites.getByProfileId(profileId)), hasLength(2));
      expect((await filters.getByProfileId(profileId)), hasLength(1));
    });

    test('leaves directory bookmarks and scan state untouched', () async {
      await seedPreProfileLibrary();

      await migrate();

      final photos = await directories.getByDirectoryId('photos');
      expect(photos!.bookmarkData, 'bookmark-photos');
      expect(photos.lastScanAt, DateTime(2024, 2, 1));
      expect(photos.tagIds, equals(<String>['tag-a']));
    });

    test('re-keys favorites onto their profile-scoped id', () async {
      await seedPreProfileLibrary();

      final profileId = (await migrate()).profileId!;

      // Reachable at the new key...
      expect(
        await favorites.getByCompositeId(
          profileId,
          'media-1',
          FavoriteItemType.media,
        ),
        isNotNull,
      );
      // ...and no stale row left behind at the old one.
      expect(
        await favorites.getByCompositeId('', 'media-1', FavoriteItemType.media),
        isNull,
      );
      expect(await favorites.getAll(), hasLength(2));
    });

    test('backs up exactly once, before mutating', () async {
      await seedPreProfileLibrary();

      await migrate();

      expect(backUpCount, 1);
    });
  });

  group('idempotence', () {
    test('a second run does nothing', () async {
      await seedPreProfileLibrary();
      final first = await migrate();

      final second = await migrate();

      expect(second.didAnything, isFalse);
      expect(backUpCount, 1, reason: 'no backup on a run with nothing to do');
      expect(await profiles.getAll(), hasLength(1));
      expect(await favorites.getAll(), hasLength(2));
      // Still in the same profile, not re-adopted into a second "Default".
      expect(
        (await directories.getByProfileId(first.profileId!)),
        hasLength(2),
      );
    });

    test('an empty database is left alone', () async {
      final report = await migrate();

      expect(report.didAnything, isFalse);
      expect(backUpCount, 0);
      expect(await profiles.getAll(), isEmpty);
    });

    test('a run interrupted midway finishes into the same profile', () async {
      // The profile exists and the tags were stamped, but the process died before
      // the directories were. A second "Default" here would strand the library.
      await seedPreProfileLibrary();
      final profile = ProfileModel(
        id: 'existing-profile',
        name: defaultProfileName,
        createdAt: DateTime(2024, 1, 1),
      ).toCollection();
      await profiles.put(profile);

      final report = await migrate();

      expect(await profiles.getAll(), hasLength(1));
      expect(report.profileId, 'existing-profile');
      expect(
        await directories.getByProfileId('existing-profile'),
        hasLength(2),
      );
    });
  });

  group('alongside the key migration', () {
    test('a legacy database converges after both run, in order', () async {
      // Rows written by the build with the byte-sum primary key, which the key
      // migration exists to rescue. The profile migration then has to move those
      // same favorites again, onto the profile-scoped key.
      await directories.put(_directory('photos'));
      await filters.put(_filter('filter-1'));
      for (final tag in <TagCollection>[_tag('tag-a'), _tag('tag-b')]) {
        tags.seedAt(legacyIsarIdForString(tag.tagId), tag);
      }
      for (final favorite in <FavoriteCollection>[
        _favorite('media-1'),
        _favorite('dir-1', type: FavoriteItemType.directory),
      ]) {
        favorites.seedAt(
          legacyIsarIdForString(
            favoriteKey(favorite.profileId, favorite.itemId, favorite.itemType),
          ),
          favorite,
        );
      }

      await const IsarKeyMigration().runOnStores(
        tags: tags,
        favorites: favorites,
        backUp: () async => backUpCount += 1,
      );
      final profileId = (await migrate()).profileId!;

      // Every row ends up addressable at the id it now computes for itself.
      expect(await tags.getByProfileId(profileId), hasLength(2));
      expect(await favorites.getAll(), hasLength(2));
      expect(
        await favorites.getByCompositeId(
          profileId,
          'media-1',
          FavoriteItemType.media,
        ),
        isNotNull,
      );
      expect(
        await favorites.getByCompositeId(
          profileId,
          'dir-1',
          FavoriteItemType.directory,
        ),
        isNotNull,
      );

      // And a relaunch settles: neither migration finds anything left to do.
      final settled = await migrate();
      expect(settled.didAnything, isFalse);
    });
  });
}
