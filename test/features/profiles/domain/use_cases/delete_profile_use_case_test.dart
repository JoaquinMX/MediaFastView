import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/isar/isar_favorites_data_source.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_cover_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/profiles/domain/entities/profile_entity.dart';
import 'package:media_fast_view/features/profiles/domain/profile_scoped_sources.dart';
import 'package:media_fast_view/features/profiles/domain/profile_validation.dart';
import 'package:media_fast_view/features/profiles/domain/repositories/profile_repository.dart';
import 'package:media_fast_view/features/profiles/domain/use_cases/delete_profile_use_case.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_saved_filter_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/saved_filter_collection.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';
import 'package:media_fast_view/features/tagging/data/models/saved_filter_model.dart';

import '../../../../helpers/in_memory_isar_stores.dart';

const String _doomed = 'profile-doomed';
const String _survivor = 'profile-survivor';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._profiles);

  final List<ProfileEntity> _profiles;
  final removed = <String>[];

  @override
  Future<List<ProfileEntity>> getProfiles() async => List.of(_profiles);

  @override
  Future<void> saveProfile(ProfileEntity profile) async {}

  @override
  Future<void> removeProfile(String id) async {
    removed.add(id);
    _profiles.removeWhere((profile) => profile.id == id);
  }
}

ProfileEntity _profile(String id) => ProfileEntity(
  id: id,
  name: id,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  late FakeIsarDatabase database;
  late InMemoryDirectoryCollectionStore directoryStore;
  late InMemoryMediaCollectionStore mediaStore;
  late InMemoryDirectoryCoverCollectionStore coverStore;
  late InMemoryTagCollectionStore tagStore;
  late InMemoryFavoriteCollectionStore favoriteStore;
  late InMemorySavedFilterCollectionStore filterStore;
  late _FakeProfileRepository profiles;
  late DeleteProfileUseCase deleteProfile;

  ProfileScopedSources sourcesFor(String profileId) {
    return ProfileScopedSources(
      directories: IsarDirectoryDataSource(
        database,
        profileId: profileId,
        directoryStoreBuilder: (_) => directoryStore,
        tagStoreBuilder: (_) => tagStore,
      ),
      media: IsarMediaDataSource(
        database,
        profileId: profileId,
        mediaStoreBuilder: (_) => mediaStore,
        directoryStoreBuilder: (_) => directoryStore,
        tagStoreBuilder: (_) => tagStore,
      ),
      tags: IsarTagDataSource(
        database,
        profileId: profileId,
        tagStoreBuilder: (_) => tagStore,
        directoryStoreBuilder: (_) => directoryStore,
        mediaStoreBuilder: (_) => mediaStore,
      ),
      favorites: IsarFavoritesDataSource(
        database,
        profileId: profileId,
        favoriteStoreBuilder: (_) => favoriteStore,
        mediaStoreBuilder: (_) => mediaStore,
        directoryStoreBuilder: (_) => directoryStore,
      ),
      filters: IsarSavedFilterDataSource(
        database,
        profileId: profileId,
        storeBuilder: (_) => filterStore,
      ),
      covers: IsarDirectoryCoverDataSource(
        database,
        profileId: profileId,
        storeBuilder: (_) => coverStore,
      ),
    );
  }

  Future<void> seedTag(String tagId, String profileId) {
    return tagStore.put(
      TagModel(
        id: tagId,
        profileId: profileId,
        name: tagId,
        color: 0xFF000000,
        createdAt: DateTime(2024, 1, 1),
      ).toCollection(),
    );
  }

  Future<void> seedDirectory(
    String id, {
    required List<String> profileIds,
    List<String> tagIds = const <String>[],
  }) {
    return directoryStore.put(
      DirectoryModel(
        id: id,
        path: '/library/$id',
        name: id,
        tagIds: tagIds,
        profileIds: profileIds,
        lastModified: DateTime(2024, 1, 1),
        bookmarkData: 'bookmark-$id',
        lastScanAt: DateTime(2024, 2, 1),
      ).toCollection(),
    );
  }

  Future<void> seedMedia(String id, String directoryId) {
    return mediaStore.put(
      MediaModel(
        id: id,
        path: '/library/$directoryId/$id',
        name: id,
        type: MediaType.image,
        size: 10,
        lastModified: DateTime(2024, 1, 1),
        directoryId: directoryId,
      ).toCollection(),
    );
  }

  setUp(() {
    database = FakeIsarDatabase();
    directoryStore = InMemoryDirectoryCollectionStore();
    mediaStore = InMemoryMediaCollectionStore();
    coverStore = InMemoryDirectoryCoverCollectionStore();
    tagStore = InMemoryTagCollectionStore();
    favoriteStore = InMemoryFavoriteCollectionStore();
    filterStore = InMemorySavedFilterCollectionStore();
    profiles = _FakeProfileRepository(<ProfileEntity>[
      _profile(_doomed),
      _profile(_survivor),
    ]);
    deleteProfile = DeleteProfileUseCase(profiles, sourcesFor);
  });

  test('refuses to delete the last profile', () async {
    final only = _FakeProfileRepository(<ProfileEntity>[_profile(_doomed)]);

    expect(
      () => DeleteProfileUseCase(only, sourcesFor)(_doomed),
      throwsA(isA<ProfileValidationException>()),
    );
  });

  test('drops a directory no other profile tracks, and its media', () async {
    await seedDirectory('solo', profileIds: <String>[_doomed]);
    await seedMedia('media-1', 'solo');

    final report = await deleteProfile(_doomed);

    expect(await directoryStore.getByDirectoryId('solo'), isNull);
    expect(await mediaStore.getAll(), isEmpty);
    expect(report.directoriesDropped, 1);
    expect(report.directoriesKept, 0);
  });

  test(
    'keeps a shared directory whole, with its bookmark and scan cache',
    () async {
      await seedTag('tag-mine', _doomed);
      await seedTag('tag-theirs', _survivor);
      await seedDirectory(
        'shared',
        profileIds: <String>[_doomed, _survivor],
        tagIds: <String>['tag-mine', 'tag-theirs'],
      );
      await seedMedia('media-1', 'shared');

      final report = await deleteProfile(_doomed);

      final survivor = await directoryStore.getByDirectoryId('shared');
      expect(survivor, isNotNull);
      expect(survivor!.profileIds, equals(<String>[_survivor]));
      expect(survivor.bookmarkData, 'bookmark-shared');
      expect(
        survivor.lastScanAt,
        DateTime(2024, 2, 1),
        reason: 'the surviving profile should not have to rescan',
      );
      expect(
        survivor.tagIds,
        equals(<String>['tag-theirs']),
        reason: "the deleted profile's tags go; the survivor's stay",
      );
      expect(
        await mediaStore.getAll(),
        hasLength(1),
        reason: 'the scan cache is shared, so it survives with the directory',
      );

      expect(report.directoriesDropped, 0);
      expect(report.directoriesKept, 1);
    },
  );

  test(
    "deletes the profile's tags, favorites and filters, and no others",
    () async {
      await seedTag('tag-mine', _doomed);
      await seedTag('tag-theirs', _survivor);
      await favoriteStore.put(
        FavoriteModel(
          itemId: 'media-1',
          profileId: _doomed,
          itemType: FavoriteItemType.media,
          addedAt: DateTime(2024, 1, 1),
        ).toCollection(),
      );
      await favoriteStore.put(
        FavoriteModel(
          itemId: 'media-1',
          profileId: _survivor,
          itemType: FavoriteItemType.media,
          addedAt: DateTime(2024, 1, 1),
        ).toCollection(),
      );
      await filterStore.put(
        SavedFilterModel(
          id: 'filter-mine',
          profileId: _doomed,
          name: 'mine',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ).toCollection(),
      );
      await filterStore.put(
        SavedFilterModel(
          id: 'filter-theirs',
          profileId: _survivor,
          name: 'theirs',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ).toCollection(),
      );

      await deleteProfile(_doomed);

      expect(await tagStore.getByProfileId(_doomed), isEmpty);
      expect(await tagStore.getByProfileId(_survivor), hasLength(1));
      expect(await favoriteStore.getByProfileId(_doomed), isEmpty);
      expect(
        await favoriteStore.getByProfileId(_survivor),
        hasLength(1),
        reason:
            'the same media favorited in both profiles is two separate rows',
      );
      expect(await filterStore.getByProfileId(_doomed), isEmpty);
      expect(await filterStore.getByProfileId(_survivor), hasLength(1));

      expect(profiles.removed, equals(<String>[_doomed]));
    },
  );

  test("deletes only the removed profile's directory covers", () async {
    final doomedCovers = IsarDirectoryCoverDataSource(
      database,
      profileId: _doomed,
      storeBuilder: (_) => coverStore,
    );
    final survivorCovers = IsarDirectoryCoverDataSource(
      database,
      profileId: _survivor,
      storeBuilder: (_) => coverStore,
    );
    final cover = DirectoryCoverEntity.media(
      directoryPath: '/library/photos',
      sourceFileName: 'cover.jpg',
      mediaType: MediaType.image,
      updatedAt: DateTime(2025),
    );
    await doomedCovers.saveCover(cover);
    await survivorCovers.saveCover(cover);

    await deleteProfile(_doomed);

    expect(await doomedCovers.getCover('/library/photos'), isNull);
    expect(await survivorCovers.getCover('/library/photos'), isNotNull);
  });
}
