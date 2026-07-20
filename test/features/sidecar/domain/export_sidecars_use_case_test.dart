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
  final path = '$folder/$name';
  return MediaEntity(
    id: generateMediaIdFromMetadata(
      size: size,
      lastModified: DateTime.fromMillisecondsSinceEpoch(mtimeMs),
      fileName: name,
    ),
    path: path,
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

  test('writes one manifest per folder and skips folders with nothing to say',
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

    final sidecar = FakeSidecarRepository();
    final useCase = ExportSidecarsUseCase(
      mediaRepository: FakeMediaRepository(<MediaEntity>[tagged, untagged, both]),
      directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
      favoritesRepository: FakeFavoritesRepository(<FavoriteEntity>[
        FavoriteEntity(
          itemId: both.id,
          itemType: FavoriteItemType.media,
          addedAt: DateTime(2021),
        ),
      ]),
      tagRepository: FakeTagRepository(<TagEntity>[family, year]),
      sidecarRepository: sidecar,
    );

    final result = await useCase();

    // /lib (folder tags only), /lib/a (IMG1), /lib/b (IMG3). No manifest that
    // is empty — /lib/a's IMG2 carried nothing, but IMG1 keeps the folder alive.
    expect(sidecar.written.keys, containsAll(<String>['/lib', '/lib/a', '/lib/b']));
    expect(sidecar.written.length, 3);

    final folderA = sidecar.written['/lib/a']!;
    expect(folderA.files.keys, <String>['IMG1.jpg']); // IMG2 skipped
    expect(folderA.files['IMG1.jpg']!.tags, <String>['Family']);
    expect(folderA.tags['Family']!.color, 0xFFFF0000);

    final folderB = sidecar.written['/lib/b']!;
    expect(folderB.files['IMG3.jpg']!.tags, <String>['Family', '2024']);
    expect(folderB.files['IMG3.jpg']!.favorite, isTrue);

    final rootManifest = sidecar.written['/lib']!;
    expect(rootManifest.folderTags, <String>['Family']);
    expect(rootManifest.files, isEmpty);

    expect(result.foldersWritten, 3);
    expect(result.filesCovered, 2); // IMG1, IMG3
    expect(result.favoritesCovered, 1); // IMG3
    expect(result.hasFailures, isFalse);
  });

  test('skips folders missing on disk without counting them as failures',
      () async {
    final root = _root('/lib', tagIds: <String>['t-family']);
    final present = _media(
      folder: '/lib/a',
      name: 'IMG1.jpg',
      tagIds: <String>['t-family'],
    );
    // Cached tagged+favorited media in a folder that no longer exists on disk.
    final stale = _media(
      folder: '/lib/gone',
      name: 'IMG3.jpg',
      tagIds: <String>['t-family', 't-2024'],
    );

    final sidecar = FakeSidecarRepository(missingFolders: <String>{'/lib/gone'});
    final useCase = ExportSidecarsUseCase(
      mediaRepository: FakeMediaRepository(<MediaEntity>[present, stale]),
      directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
      favoritesRepository: FakeFavoritesRepository(<FavoriteEntity>[
        FavoriteEntity(
          itemId: stale.id,
          itemType: FavoriteItemType.media,
          addedAt: DateTime(2021),
        ),
      ]),
      tagRepository: FakeTagRepository(<TagEntity>[family, year]),
      sidecarRepository: sidecar,
    );

    final result = await useCase();

    // The stale folder is skipped, not failed, and its file/favorite are not
    // counted as saved.
    expect(sidecar.written.keys, isNot(contains('/lib/gone')));
    expect(result.foldersSkippedMissing, 1);
    expect(result.hasFailures, isFalse);
    expect(result.filesCovered, 1); // only IMG1 reached disk
    expect(result.favoritesCovered, 0); // IMG3's favorite was in the stale folder
    expect(result.describe(), contains('no longer exist on disk'));
  });

  test('writes nothing when there are no tags or favorites', () async {
    final root = _root('/lib');
    final sidecar = FakeSidecarRepository();
    final useCase = ExportSidecarsUseCase(
      mediaRepository: FakeMediaRepository(<MediaEntity>[
        _media(folder: '/lib/a', name: 'IMG1.jpg', tagIds: const <String>[]),
      ]),
      directoryRepository: FakeDirectoryRepository(<DirectoryEntity>[root]),
      favoritesRepository: FakeFavoritesRepository(),
      tagRepository: FakeTagRepository(),
      sidecarRepository: sidecar,
    );

    final result = await useCase();

    expect(sidecar.written, isEmpty);
    expect(result.foldersWritten, 0);
  });
}
