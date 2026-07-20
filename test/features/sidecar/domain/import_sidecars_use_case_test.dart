import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_file_entry.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_file_stat.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_folder_data.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_manifest.dart';
import 'package:media_fast_view/features/sidecar/domain/use_cases/import_sidecars_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/create_tag_use_case.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:media_fast_view/shared/utils/media_id_utils.dart';

import '../sidecar_fakes.dart';

void main() {
  test('merges tags by name, unions assignments, and re-links by live id',
      () async {
    const rootPath = '/lib';
    final rootId = generateDirectoryId(rootPath);
    final root = DirectoryEntity(
      id: rootId,
      path: rootPath,
      name: 'lib',
      thumbnailPath: null,
      tagIds: const <String>[],
      lastModified: DateTime(2020),
      bookmarkData: 'bm',
    );

    // 'Family' already exists in the profile; the manifest references it as
    // 'family' (different case) and must reuse it, not create a duplicate.
    final familyTag = TagEntity(
      id: 't-existing',
      name: 'Family',
      color: 0xFFFF0000,
      createdAt: DateTime(2020),
    );

    // IMG1 is already cached with the Family tag; the import must union 'Travel'
    // onto it rather than replace it.
    final img1Id = generateMediaIdFromMetadata(
      size: 100,
      lastModified: DateTime.fromMillisecondsSinceEpoch(1000),
      fileName: 'IMG1.jpg',
    );
    final existingImg1 = MediaEntity(
      id: img1Id,
      path: '/lib/a/IMG1.jpg',
      name: 'IMG1.jpg',
      type: MediaType.image,
      size: 100,
      lastModified: DateTime.fromMillisecondsSinceEpoch(1000),
      tagIds: const <String>['t-existing'],
      directoryId: generateDirectoryId('/lib/a'),
    );

    final folderA = SidecarFolderData(
      folderPath: '/lib/a',
      manifest: SidecarManifest(
        generatedAt: DateTime(2026),
        tags: const <String, SidecarTagDef>{
          'family': SidecarTagDef(color: 0xFFFF0000),
          'Travel': SidecarTagDef(color: 0xFF0000FF),
        },
        files: const <String, SidecarFileEntry>{
          'IMG1.jpg': SidecarFileEntry(
            size: 100,
            mtimeMs: 1000,
            tags: <String>['family', 'Travel'],
            favorite: true,
          ),
          'GONE.jpg': SidecarFileEntry(
            size: 5,
            mtimeMs: 5,
            tags: <String>['family'],
          ),
        },
      ),
      liveStats: const <String, SidecarFileStat>{
        'IMG1.jpg': SidecarFileStat(size: 100, mtimeMs: 1000),
      },
      missingFileNames: const <String>{'GONE.jpg'},
    );

    final rootFolder = SidecarFolderData(
      folderPath: rootPath,
      manifest: SidecarManifest(
        generatedAt: DateTime(2026),
        folderTags: const <String>['family'],
        folderFavorite: true,
        tags: const <String, SidecarTagDef>{
          'family': SidecarTagDef(color: 0xFFFF0000),
        },
      ),
      liveStats: const <String, SidecarFileStat>{},
      missingFileNames: const <String>{},
    );

    final mediaRepository = FakeMediaRepository(<MediaEntity>[existingImg1]);
    final directoryRepository =
        FakeDirectoryRepository(<DirectoryEntity>[root]);
    final favoritesRepository = FakeFavoritesRepository();
    final tagRepository = FakeTagRepository(<TagEntity>[familyTag]);
    final sidecarRepository = FakeSidecarRepository(
      readData: <String, List<SidecarFolderData>>{
        rootId: <SidecarFolderData>[folderA, rootFolder],
      },
    );

    final useCase = ImportSidecarsUseCase(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
      tagRepository: tagRepository,
      createTagUseCase:
          CreateTagUseCase(tagRepository, generateId: () => 'tag-travel'),
      assignTagUseCase: AssignTagUseCase(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
      ),
      sidecarRepository: sidecarRepository,
      mediaTypeResolver: (_) => MediaType.image,
    );

    final result = await useCase();

    // Re-link: one media upserted, keyed by the id recomputed from live stat.
    expect(mediaRepository.upserted, hasLength(1));
    final upserted = mediaRepository.upserted.single;
    expect(upserted.id, img1Id);
    // Union: existing Family tag preserved, new Travel tag added.
    expect(upserted.tagIds.toSet(), <String>{'t-existing', 'tag-travel'});

    expect(result.filesLinked, 1);
    expect(result.filesNotFound, 1); // GONE.jpg
    expect(result.tagsCreated, 1); // Travel only; 'family' matched existing
    expect(result.manifestsRead, 2);

    // Favorites: IMG1 (media) and the folder itself (directory).
    expect(result.favoritesApplied, 2);
    final favoriteTypes =
        favoritesRepository.added.map((f) => f.itemType).toList();
    expect(favoriteTypes, containsAll(<FavoriteItemType>[
      FavoriteItemType.media,
      FavoriteItemType.directory,
    ]));
    expect(
      favoritesRepository.added.map((f) => f.itemId),
      containsAll(<String>[img1Id, rootId]),
    );

    // Folder-level tags applied to the tracked root by re-derived id.
    expect(directoryRepository.updatedTags[rootId], <String>['t-existing']);
  });

  test('returns an empty result when no manifests are found', () async {
    final root = DirectoryEntity(
      id: generateDirectoryId('/lib'),
      path: '/lib',
      name: 'lib',
      thumbnailPath: null,
      tagIds: const <String>[],
      lastModified: DateTime(2020),
      bookmarkData: 'bm',
    );
    final tagRepository = FakeTagRepository();
    final directoryRepository =
        FakeDirectoryRepository(<DirectoryEntity>[root]);

    final useCase = ImportSidecarsUseCase(
      directoryRepository: directoryRepository,
      mediaRepository: FakeMediaRepository(),
      favoritesRepository: FakeFavoritesRepository(),
      tagRepository: tagRepository,
      createTagUseCase: CreateTagUseCase(tagRepository),
      assignTagUseCase: AssignTagUseCase(
        directoryRepository: directoryRepository,
        mediaRepository: FakeMediaRepository(),
      ),
      sidecarRepository: FakeSidecarRepository(),
      mediaTypeResolver: (_) => MediaType.image,
    );

    final result = await useCase();

    expect(result.manifestsRead, 0);
    expect(result.filesLinked, 0);
    expect(result.foundNothing, isTrue);
  });
}
