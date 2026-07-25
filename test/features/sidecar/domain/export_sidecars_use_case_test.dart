import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/sidecar/domain/use_cases/export_sidecars_use_case.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:media_fast_view/shared/utils/media_id_utils.dart';

import '../sidecar_fakes.dart';

MediaEntity _media({
  required String folder,
  required String name,
  required List<String> tagIds,
  int size = 100,
  int mtimeMs = 1000,
}) {
  return MediaEntity(
    id: generateMediaIdFromMetadata(
      size: size,
      lastModified: DateTime.fromMillisecondsSinceEpoch(mtimeMs),
      fileName: name,
    ),
    path: '$folder/$name',
    name: name,
    type: MediaType.image,
    size: size,
    lastModified: DateTime.fromMillisecondsSinceEpoch(mtimeMs),
    tagIds: tagIds,
    directoryId: generateDirectoryId(folder),
  );
}

DirectoryEntity _root(String path, {List<String> tagIds = const <String>[]}) {
  return DirectoryEntity(
    id: generateDirectoryId(path),
    path: path,
    name: path.split('/').last,
    thumbnailPath: null,
    tagIds: tagIds,
    lastModified: DateTime(2020),
    bookmarkData: 'bookmark:$path',
  );
}

void main() {
  final family = TagEntity(
    id: 't-family',
    name: 'Family',
    color: 0xFFFF0000,
    createdAt: DateTime(2020),
  );
  final year = TagEntity(
    id: 't-2024',
    name: '2024',
    color: 0xFF00FF00,
    createdAt: DateTime(2020),
  );

  test(
    'embeds one manifest per meaningful folder in a portable root',
    () async {
      final root = _root('/lib', tagIds: <String>['t-family']);
      final tagged = _media(
        folder: '/lib/a',
        name: 'IMG1.jpg',
        tagIds: <String>['t-family'],
      );
      final untagged = _media(
        folder: '/lib/a',
        name: 'IMG2.jpg',
        tagIds: const <String>[],
      );
      final both = _media(
        folder: '/lib/b',
        name: 'IMG3.jpg',
        tagIds: <String>['t-family', 't-2024'],
      );

      final useCase = ExportSidecarsUseCase(
        mediaRepository: FakeMediaRepository(<MediaEntity>[
          tagged,
          untagged,
          both,
        ]),
        directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
        favoritesRepository: FakeFavoritesRepository(<FavoriteEntity>[
          FavoriteEntity(
            itemId: both.id,
            itemType: FavoriteItemType.media,
            addedAt: DateTime(2021),
          ),
        ]),
        tagRepository: FakeTagRepository(<TagEntity>[family, year]),
      );

      final preparation = await useCase();

      expect(preparation.backup.roots, hasLength(1));
      final manifests =
          preparation.backup.roots.single.manifestsByRelativeFolder;
      expect(manifests.keys, containsAll(<String>['.', 'a', 'b']));
      expect(manifests, hasLength(3));

      expect(manifests['a']!.files.keys, <String>['IMG1.jpg']);
      expect(manifests['a']!.files['IMG1.jpg']!.tags, <String>['Family']);
      expect(manifests['a']!.tags['Family']!.color, 0xFFFF0000);
      expect(manifests['b']!.files['IMG3.jpg']!.tags, <String>[
        'Family',
        '2024',
      ]);
      expect(manifests['b']!.files['IMG3.jpg']!.favorite, isTrue);
      expect(manifests['.']!.folderTags, <String>['Family']);

      expect(preparation.result.rootsSaved, 1);
      expect(preparation.result.manifestsSaved, 3);
      expect(preparation.result.filesCovered, 2);
      expect(preparation.result.favoritesCovered, 1);
      expect(preparation.result.hasFailures, isFalse);
    },
  );

  test(
    'keeps cached metadata for folders that may be temporarily offline',
    () async {
      final root = _root('/lib');
      final stale = _media(
        folder: '/lib/offline',
        name: 'IMG3.jpg',
        tagIds: <String>['t-family'],
      );
      final useCase = ExportSidecarsUseCase(
        mediaRepository: FakeMediaRepository(<MediaEntity>[stale]),
        directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
        favoritesRepository: FakeFavoritesRepository(),
        tagRepository: FakeTagRepository(<TagEntity>[family]),
      );

      final preparation = await useCase();

      expect(
        preparation
            .backup
            .roots
            .single
            .manifestsByRelativeFolder['offline']!
            .files,
        contains('IMG3.jpg'),
      );
      expect(preparation.result.filesCovered, 1);
    },
  );

  test('assigns a folder to the deepest nested tracked root', () async {
    final outer = _root('/lib');
    final inner = _root('/lib/photos');
    final media = _media(
      folder: '/lib/photos/trip',
      name: 'IMG.jpg',
      tagIds: <String>['t-family'],
    );
    final useCase = ExportSidecarsUseCase(
      mediaRepository: FakeMediaRepository(<MediaEntity>[media]),
      directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[
        outer,
        inner,
      ]),
      favoritesRepository: FakeFavoritesRepository(),
      tagRepository: FakeTagRepository(<TagEntity>[family]),
    );

    final preparation = await useCase();

    expect(preparation.backup.roots, hasLength(1));
    expect(preparation.backup.roots.single.originalPath, inner.path);
    expect(
      preparation.backup.roots.single.manifestsByRelativeFolder,
      contains('trip'),
    );
  });

  test('creates an empty backup when there are no tags or favorites', () async {
    final root = _root('/lib');
    final useCase = ExportSidecarsUseCase(
      mediaRepository: FakeMediaRepository(<MediaEntity>[
        _media(folder: '/lib/a', name: 'IMG1.jpg', tagIds: const <String>[]),
      ]),
      directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
      favoritesRepository: FakeFavoritesRepository(),
      tagRepository: FakeTagRepository(),
    );

    final preparation = await useCase();

    expect(preparation.backup.isEmpty, isTrue);
    expect(preparation.result.manifestsSaved, 0);
  });
}
