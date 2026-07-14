import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/file_transfer_result.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/reconcile_transferred_media_use_case.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:media_fast_view/shared/utils/media_id_utils.dart';

import '../../../../helpers/in_memory_isar_stores.dart';

/// A bookmark service that never touches the platform channel. The reconciler
/// only uses it to bracket its filesystem reads in security-scoped access, which
/// is a no-op in tests.
class _NoopBookmarkService implements BookmarkService {
  @override
  Future<String> startAccessingBookmark(String bookmarkData) async => '/scope';

  @override
  Future<void> stopAccessingBookmark(String bookmarkData) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFavoritesRepository implements FavoritesRepository {
  final List<FavoriteEntity> favorites = <FavoriteEntity>[];

  @override
  Future<List<FavoriteEntity>> getFavorites() async => List.of(favorites);

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async {
    return favorites.any((f) => f.itemId == itemId && f.itemType == type);
  }

  @override
  Future<void> addFavorites(List<FavoriteEntity> newFavorites) async {
    favorites.addAll(newFavorites);
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    favorites.removeWhere((f) => f.itemId == itemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDirectoryRepository implements DirectoryRepository {
  final Map<String, DirectoryEntity> directories = <String, DirectoryEntity>{};
  final List<({String id, String? path, String? name})> metadataUpdates = [];

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async => directories[id];

  @override
  Future<void> updateDirectoryMetadata(
    String directoryId, {
    String? path,
    String? name,
    String? bookmarkData,
  }) async {
    metadataUpdates.add((id: directoryId, path: path, name: name));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryMediaCollectionStore mediaStore;
  late IsarMediaDataSource mediaDataSource;
  late _FakeFavoritesRepository favorites;
  late _FakeDirectoryRepository directories;
  late ReconcileTransferredMediaUseCase reconcile;

  late InMemoryDirectoryCollectionStore directoryStore;

  setUp(() async {
    mediaStore = InMemoryMediaCollectionStore();
    directoryStore = InMemoryDirectoryCollectionStore();
    mediaDataSource = IsarMediaDataSource(
      FakeIsarDatabase(),
      profileId: 'profile-1',
      mediaStoreBuilder: (_) => mediaStore,
      directoryStoreBuilder: (_) => directoryStore,
      tagStoreBuilder: (_) => InMemoryTagCollectionStore(),
    );

    // Media is visible to a profile through the directory that contains it, so
    // both ends of a transfer have to be directories the profile actually owns.
    for (final path in <String>['/library/Photos', '/library/Trips']) {
      await directoryStore.put(
        DirectoryModel(
          id: generateDirectoryId(path),
          path: path,
          name: path.split('/').last,
          profileIds: const <String>['profile-1'],
          lastModified: DateTime.utc(2024, 1, 1),
        ).toCollection(),
      );
    }
    favorites = _FakeFavoritesRepository();
    directories = _FakeDirectoryRepository();
    reconcile = ReconcileTransferredMediaUseCase(
      mediaDataSource,
      favorites,
      directories,
      _NoopBookmarkService(),
    );
  });

  const sourceDir = '/library/Photos';
  const destinationDir = '/library/Trips';
  final modified = DateTime.utc(2024, 5, 1);

  String fileId(String name, {int size = 100, DateTime? at}) {
    return generateMediaIdFromMetadata(
      size: size,
      lastModified: at ?? modified,
      fileName: name,
    );
  }

  MediaEntity buildFile({
    required String name,
    List<String> tagIds = const ['holiday'],
    int size = 100,
  }) {
    return MediaEntity(
      id: fileId(name, size: size),
      path: '$sourceDir/$name',
      name: name,
      type: MediaType.image,
      size: size,
      lastModified: modified,
      tagIds: tagIds,
      directoryId: generateDirectoryId(sourceDir),
    );
  }

  Future<void> seed(MediaEntity media) {
    return mediaDataSource.upsertMedia([
      MediaModel(
        id: media.id,
        path: media.path,
        name: media.name,
        type: media.type,
        size: media.size,
        lastModified: media.lastModified,
        tagIds: media.tagIds,
        directoryId: media.directoryId,
      ),
    ]);
  }

  /// The native result for a transfer that preserved the file's metadata — what
  /// a same-volume move produces.
  FileTransferResult movedTo(
    String path, {
    bool renamed = false,
    bool sameVolume = true,
    int size = 100,
    DateTime? at,
  }) {
    return FileTransferResult(
      sourcePath: '',
      destinationPath: path,
      renamed: renamed,
      sameVolume: sameVolume,
      size: size,
      lastModified: at ?? modified,
      isDirectory: false,
    );
  }

  group('moving a file', () {
    test(
      'keeps its identity, tags and favorite when the metadata survives',
      () async {
        final media = buildFile(name: 'beach.jpg');
        await seed(media);
        favorites.favorites.add(
          FavoriteEntity(
            itemId: media.id,
            itemType: FavoriteItemType.media,
            addedAt: DateTime.utc(2023),
          ),
        );

        final result = await reconcile(
          source: media,
          transfer: movedTo('$destinationDir/beach.jpg'),
          destinationDirectoryPath: destinationDir,
          mode: TransferMode.move,
        );

        expect(result.identityChanged, isFalse);
        expect(result.media.id, media.id);

        final rows = await mediaDataSource.getMedia();
        expect(rows, hasLength(1));
        expect(rows.single.path, '$destinationDir/beach.jpg');
        expect(rows.single.directoryId, generateDirectoryId(destinationDir));
        expect(rows.single.tagIds, ['holiday']);

        // The favorite is keyed by an id that did not change, so it needs no
        // repair.
        expect(favorites.favorites.single.itemId, media.id);
        expect(favorites.favorites.single.addedAt, DateTime.utc(2023));
      },
    );

    test('re-keys and carries tags when a rename changed the name', () async {
      final media = buildFile(name: 'beach.jpg');
      await seed(media);
      favorites.favorites.add(
        FavoriteEntity(
          itemId: media.id,
          itemType: FavoriteItemType.media,
          addedAt: DateTime.utc(2023),
        ),
      );

      // "Keep both" renamed the file, and the name is part of the id — so the
      // identity changes even though this was a same-volume move.
      final result = await reconcile(
        source: media,
        transfer: movedTo('$destinationDir/beach 2.jpg', renamed: true),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.move,
      );

      final expectedId = fileId('beach 2.jpg');
      expect(result.identityChanged, isTrue);
      expect(result.media.id, expectedId);
      expect(expectedId, isNot(media.id));

      final rows = await mediaDataSource.getMedia();
      expect(rows, hasLength(1), reason: 'the old row must be gone');
      expect(rows.single.id, expectedId);
      expect(rows.single.tagIds, ['holiday']);

      // The favorite follows the item to its new id, keeping its original
      // position in the recently-favorited ordering.
      expect(favorites.favorites.single.itemId, expectedId);
      expect(favorites.favorites.single.addedAt, DateTime.utc(2023));
    });

    test('re-keys when a cross-volume move changed the timestamp', () async {
      final media = buildFile(name: 'beach.jpg');
      await seed(media);

      final landedAt = DateTime.utc(2024, 6, 9);
      final result = await reconcile(
        source: media,
        transfer: movedTo(
          '$destinationDir/beach.jpg',
          sameVolume: false,
          at: landedAt,
        ),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.move,
      );

      expect(result.identityChanged, isTrue);
      expect(result.media.id, fileId('beach.jpg', at: landedAt));

      final rows = await mediaDataSource.getMedia();
      expect(rows, hasLength(1));
      expect(rows.single.tagIds, ['holiday']);
    });
  });

  group('copying a file', () {
    test('leaves the source intact and gives the copy the tags', () async {
      final media = buildFile(name: 'beach.jpg');
      await seed(media);
      favorites.favorites.add(
        FavoriteEntity(
          itemId: media.id,
          itemType: FavoriteItemType.media,
          addedAt: DateTime.utc(2023),
        ),
      );

      // The native copy stamps a fresh modification time, so the copy gets an
      // identity of its own.
      final copiedAt = DateTime.utc(2024, 7, 4);
      final result = await reconcile(
        source: media,
        transfer: movedTo('$destinationDir/beach.jpg', at: copiedAt),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.copy,
      );

      final rows = await mediaDataSource.getMedia();
      expect(rows, hasLength(2), reason: 'the source row must survive a copy');

      final copy = rows.firstWhere((r) => r.id == result.media.id);
      final original = rows.firstWhere((r) => r.id == media.id);
      expect(original.path, '$sourceDir/beach.jpg');
      expect(original.tagIds, ['holiday']);
      expect(copy.path, '$destinationDir/beach.jpg');
      expect(copy.tagIds, ['holiday']);

      // A favorite is a curated pointer to an item; duplicating the item should
      // not duplicate the entry in the favorites grid.
      expect(favorites.favorites, hasLength(1));
      expect(favorites.favorites.single.itemId, media.id);
    });

    test('can be told not to carry the tags over', () async {
      final media = buildFile(name: 'beach.jpg');
      await seed(media);

      final result = await reconcile(
        source: media,
        transfer: movedTo(
          '$destinationDir/beach.jpg',
          at: DateTime.utc(2024, 7, 4),
        ),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.copy,
        copyInheritsTags: false,
      );

      final rows = await mediaDataSource.getMedia();
      final copy = rows.firstWhere((r) => r.id == result.media.id);
      expect(copy.tagIds, isEmpty);
    });

    test(
      'refuses to persist a copy that kept its source id, rather than '
      'overwriting the original',
      () async {
        final media = buildFile(name: 'beach.jpg');
        await seed(media);

        // Simulates the native modification-time stamp failing: the copy hashes
        // to its source's id, and the cache is keyed by that id — persisting it
        // would silently overwrite the original's record.
        final result = await reconcile(
          source: media,
          transfer: movedTo('$destinationDir/beach.jpg'),
          destinationDirectoryPath: destinationDir,
          mode: TransferMode.copy,
        );

        expect(result.identityChanged, isFalse);

        final rows = await mediaDataSource.getMedia();
        expect(rows, hasLength(1));
        expect(
          rows.single.path,
          '$sourceDir/beach.jpg',
          reason: 'the original must still point at its own location',
        );
        expect(rows.single.tagIds, ['holiday']);
      },
    );
  });

  group('moving a directory', () {
    test('re-keys the folder and every row beneath it', () async {
      const folder = '$sourceDir/Summer';
      final folderMedia = MediaEntity(
        id: generateMediaIdFromPath(folder),
        path: folder,
        name: 'Summer',
        type: MediaType.directory,
        size: 0,
        lastModified: modified,
        tagIds: const ['trip'],
        directoryId: generateDirectoryId(sourceDir),
      );
      await seed(folderMedia);

      // A tagged file inside the folder, indexed under the folder's own grid.
      final child = MediaModel(
        id: fileId('sunset.jpg'),
        path: '$folder/sunset.jpg',
        name: 'sunset.jpg',
        type: MediaType.image,
        size: 100,
        lastModified: modified,
        tagIds: const ['sunset'],
        directoryId: generateDirectoryId(folder),
      );
      await mediaDataSource.upsertMedia([child]);

      const newFolder = '$destinationDir/Summer';
      await reconcile(
        source: folderMedia,
        transfer: FileTransferResult(
          sourcePath: folder,
          destinationPath: newFolder,
          renamed: false,
          sameVolume: true,
          size: 0,
          lastModified: modified,
          isDirectory: true,
        ),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.move,
      );

      final rows = await mediaDataSource.getMedia();
      expect(rows, hasLength(2));

      // A directory's id is derived from its path, so a move always changes it.
      final movedFolder = rows.firstWhere((r) => r.type == MediaType.directory);
      expect(movedFolder.id, generateMediaIdFromPath(newFolder));
      expect(movedFolder.path, newFolder);
      expect(movedFolder.tagIds, ['trip']);
      expect(movedFolder.directoryId, generateDirectoryId(destinationDir));

      // The child's path is rebased and it is re-attributed to the folder's new
      // id, with its tags intact.
      final movedChild = rows.firstWhere((r) => r.type == MediaType.image);
      expect(movedChild.path, '$newFolder/sunset.jpg');
      expect(movedChild.directoryId, generateDirectoryId(newFolder));
      expect(movedChild.tagIds, ['sunset']);
    });

    test('re-keys a tracked library root through the directory record', () async {
      const root = '/library/Photos';
      final rootId = generateDirectoryId(root);
      directories.directories[rootId] = DirectoryEntity(
        id: rootId,
        path: root,
        name: 'Photos',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: modified,
      );

      final rootMedia = MediaEntity(
        id: rootId,
        path: root,
        name: 'Photos',
        type: MediaType.directory,
        size: 0,
        lastModified: modified,
        tagIds: const [],
        directoryId: generateDirectoryId('/library'),
      );

      await reconcile(
        source: rootMedia,
        transfer: FileTransferResult(
          sourcePath: root,
          destinationPath: '/archive/Photos',
          renamed: false,
          sameVolume: true,
          size: 0,
          lastModified: modified,
          isDirectory: true,
        ),
        destinationDirectoryPath: '/archive',
        mode: TransferMode.move,
      );

      // Re-keying the record is delegated, so the scan fingerprints, tags and
      // bookmark on it survive.
      expect(directories.metadataUpdates, hasLength(1));
      expect(directories.metadataUpdates.single.id, rootId);
      expect(directories.metadataUpdates.single.path, '/archive/Photos');
    });
  });

  group('regression', () {
    test(
      'a rescan of the destination after a move does not wipe the tags',
      () async {
        final media = buildFile(name: 'beach.jpg');
        await seed(media);

        await reconcile(
          source: media,
          transfer: movedTo('$destinationDir/beach.jpg'),
          destinationDirectoryPath: destinationDir,
          mode: TransferMode.move,
        );

        // Replays exactly what MediaViewModel.loadMedia() does on the
        // destination: the filesystem scan always yields empty tags, and the
        // only thing that puts them back is a persisted row matched by id
        // *within that directory*. Reconciling first is what makes this a no-op
        // instead of a data loss.
        final destinationId = generateDirectoryId(destinationDir);
        final scanned = MediaModel(
          id: fileId('beach.jpg'),
          path: '$destinationDir/beach.jpg',
          name: 'beach.jpg',
          type: MediaType.image,
          size: 100,
          lastModified: modified,
          tagIds: const [],
          directoryId: destinationId,
        );

        final persisted = await mediaDataSource.getMediaForDirectory(
          destinationId,
        );
        final byId = {for (final m in persisted) m.id: m};
        final merged = scanned.copyWith(
          tagIds: byId[scanned.id]?.tagIds ?? scanned.tagIds,
        );

        await mediaDataSource.removeMediaForDirectory(destinationId);
        await mediaDataSource.upsertMedia([merged]);

        final rows = await mediaDataSource.getMedia();
        expect(rows.single.tagIds, ['holiday']);
      },
    );

    test('a rescan of the source after a move does not delete the row', () async {
      final media = buildFile(name: 'beach.jpg');
      await seed(media);

      await reconcile(
        source: media,
        transfer: movedTo('$destinationDir/beach.jpg'),
        destinationDirectoryPath: destinationDir,
        mode: TransferMode.move,
      );

      // The source directory rescans and clears its own rows. The moved file now
      // belongs to the destination, so it must not be caught by that sweep.
      await mediaDataSource.removeMediaForDirectory(
        generateDirectoryId(sourceDir),
      );

      final rows = await mediaDataSource.getMedia();
      expect(rows, hasLength(1));
      expect(rows.single.tagIds, ['holiday']);
    });
  });
}
