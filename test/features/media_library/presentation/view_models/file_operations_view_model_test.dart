import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/error/app_error.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/file_transfer_result.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/file_operations_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/delete_directory_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/delete_file_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/reconcile_transferred_media_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/transfer_media_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/validate_path_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/file_operations_view_model.dart';
import 'package:path/path.dart' as p;

import '../../../../helpers/in_memory_isar_stores.dart';

/// Records the delete calls routed through the repository so we can assert the
/// enclosing directory bookmark was threaded through.
class _RecordingFileOperationsRepository implements FileOperationsRepository {
  String? deletedFilePath;
  String? deletedFileBookmark;
  int deleteFileCalls = 0;

  String? deletedDirPath;
  String? deletedDirBookmark;
  int deleteDirCalls = 0;

  /// Every path passed to a delete, in call order.
  final List<String> deletedPaths = <String>[];

  /// Paths that should fail, mapped to the failure message.
  final Map<String, String> failures = <String, String>{};

  @override
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    deleteFileCalls++;
    deletedFilePath = filePath;
    deletedFileBookmark = bookmarkData;
    _record(filePath);
  }

  @override
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    deleteDirCalls++;
    deletedDirPath = directoryPath;
    deletedDirBookmark = bookmarkData;
    _record(directoryPath);
  }

  /// Transfers, in call order.
  final List<
    ({
      String source,
      String destination,
      String? sourceBookmark,
      String? destinationBookmark,
      ConflictStrategy strategy,
      TransferMode mode,
    })
  >
  transfers = [];

  /// When set, the next transfer reports the destination as already taken.
  String? conflictOnNextTransfer;

  @override
  Future<FileTransferResult> moveItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _transfer(
      sourcePath,
      destinationDirectoryPath,
      sourceBookmarkData,
      destinationBookmarkData,
      conflictStrategy,
      TransferMode.move,
    );
  }

  @override
  Future<FileTransferResult> copyItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _transfer(
      sourcePath,
      destinationDirectoryPath,
      sourceBookmarkData,
      destinationBookmarkData,
      conflictStrategy,
      TransferMode.copy,
    );
  }

  Future<FileTransferResult> _transfer(
    String sourcePath,
    String destinationDirectoryPath,
    String? sourceBookmark,
    String? destinationBookmark,
    ConflictStrategy strategy,
    TransferMode mode,
  ) async {
    transfers.add((
      source: sourcePath,
      destination: destinationDirectoryPath,
      sourceBookmark: sourceBookmark,
      destinationBookmark: destinationBookmark,
      strategy: strategy,
      mode: mode,
    ));

    final conflict = conflictOnNextTransfer;
    if (conflict != null && strategy == ConflictStrategy.fail) {
      throw DestinationExistsError(
        'already exists',
        destinationPath: conflict,
        suggestedPath: conflict.replaceFirst('.jpg', ' 2.jpg'),
      );
    }

    final name = p.basename(sourcePath);
    return FileTransferResult(
      sourcePath: sourcePath,
      destinationPath: p.join(destinationDirectoryPath, name),
      renamed: false,
      sameVolume: true,
      size: 1,
      lastModified: DateTime(2021, 1, 1),
      isDirectory: false,
    );
  }

  void _record(String path) {
    final failure = failures[path];
    if (failure != null) {
      throw Exception(failure);
    }
    deletedPaths.add(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// The reconciler is exercised in its own suite; here it only has to exist, so
/// it is backed by throwaway in-memory stores.
class _NoopBookmarkService implements BookmarkService {
  @override
  Future<String> startAccessingBookmark(String bookmarkData) async => '/scope';

  @override
  Future<void> stopAccessingBookmark(String bookmarkData) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

IsarMediaDataSource _inMemoryMediaDataSource() {
  return IsarMediaDataSource(
    FakeIsarDatabase(),
    mediaStoreBuilder: (_) => InMemoryMediaCollectionStore(),
    directoryStoreBuilder: (_) => InMemoryDirectoryCollectionStore(),
  );
}

class _FakeDirectoryRepository implements DirectoryRepository {
  _FakeDirectoryRepository(this._byId, {List<DirectoryEntity>? all})
      : _all = all ?? _byId.values.toList();

  final Map<String, DirectoryEntity> _byId;
  final List<DirectoryEntity> _all;

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async => _byId[id];

  @override
  Future<List<DirectoryEntity>> getDirectories() async => _all;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository({this.favorite = false});

  bool favorite;

  /// When set, overrides [favorite] with per-id answers.
  Set<String>? favoriteIds;
  final List<String> removedIds = <String>[];

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async =>
      favoriteIds?.contains(itemId) ?? favorite;

  @override
  Future<void> removeFavorite(String itemId) async {
    removedIds.add(itemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

MediaEntity _media({
  MediaType type = MediaType.image,
  String directoryId = 'dir-1',
}) {
  return MediaEntity(
    id: 'media-1',
    path: '/library/photos/image.jpg',
    name: 'image.jpg',
    type: type,
    size: 1024,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: directoryId,
  );
}

/// A file in the tracked `/library` root, keyed by [name] for readable ids.
MediaEntity _file(String name, {String? path}) {
  return MediaEntity(
    id: name,
    path: path ?? '/library/$name',
    name: name,
    type: MediaType.image,
    size: 1024,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: 'dir-1',
  );
}

/// A subdirectory of the tracked `/library` root, which the scan does not track
/// as a directory of its own.
MediaEntity _directoryMedia(String name, String path) {
  return MediaEntity(
    id: name,
    path: path,
    name: name,
    type: MediaType.directory,
    size: 0,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: 'dir-1',
  );
}

DirectoryEntity _directory({String? bookmarkData}) {
  return DirectoryEntity(
    id: 'dir-1',
    path: '/library',
    name: 'library',
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2020, 1, 1),
    bookmarkData: bookmarkData,
  );
}

void main() {
  late _RecordingFileOperationsRepository repo;
  late _FakeDirectoryRepository directoryRepo;
  late _FakeFavoritesRepository favoritesRepo;
  late IsarMediaDataSource mediaDataSource;

  FileOperationsViewModel buildViewModel() {
    return FileOperationsViewModel(
      DeleteFileUseCase(repo),
      DeleteDirectoryUseCase(repo),
      ValidatePathUseCase(repo),
      directoryRepo,
      favoritesRepo,
      MoveMediaUseCase(repo),
      CopyMediaUseCase(repo),
      ReconcileTransferredMediaUseCase(
        mediaDataSource,
        favoritesRepo,
        directoryRepo,
        _NoopBookmarkService(),
      ),
      mediaDataSource,
    );
  }

  setUp(() {
    repo = _RecordingFileOperationsRepository();
    directoryRepo = _FakeDirectoryRepository({
      'dir-1': _directory(bookmarkData: 'BOOKMARK-DATA'),
    });
    favoritesRepo = _FakeFavoritesRepository(favorite: true);
    mediaDataSource = _inMemoryMediaDataSource();
  });

  Future<void> seed(List<MediaEntity> items) {
    return mediaDataSource.upsertMedia([
      for (final item in items)
        MediaModel(
          id: item.id,
          path: item.path,
          name: item.name,
          type: item.type,
          size: item.size,
          lastModified: item.lastModified,
          tagIds: item.tagIds,
          directoryId: item.directoryId,
        ),
    ]);
  }


  test('does not delete when deleteFromSource is disabled', () async {
    final viewModel = buildViewModel();

    await viewModel.deleteMedia(_media(), deleteFromSource: false);

    expect(viewModel.debugState, isA<FileOperationsError>());
    expect(repo.deleteFileCalls, 0);
  });

  // The real delete path is macOS-only (moves to Trash). On other hosts the
  // view model short-circuits with an error, so only assert the routing where
  // it actually runs.
  final macOnly = Platform.isMacOS ? false : 'macOS-only delete path';

  group('purging the cached row', () {
    test(
      'a deleted file stops being cached',
      () async {
        final media = _media();
        await seed([media]);

        await buildViewModel().deleteMedia(media, deleteFromSource: true);

        // Nothing rescans the directory any more, so the row would otherwise
        // linger: still counted in the folder badges, still matched by tag
        // filters, still listed on the tags screen.
        expect(await mediaDataSource.getMedia(), isEmpty);
      },
      skip: macOnly,
    );

    test(
      'deleting a directory also stops caching everything under it',
      () async {
        final folder = MediaEntity(
          id: 'folder',
          path: '/library/vacation',
          name: 'vacation',
          type: MediaType.directory,
          size: 0,
          lastModified: DateTime(2020, 1, 1),
          tagIds: const [],
          directoryId: 'dir-1',
        );
        final child = _file('nested.jpg', path: '/library/vacation/nested.jpg');
        final bystander = _file('keep.jpg', path: '/library/keep.jpg');
        await seed([folder, child, bystander]);

        await buildViewModel().deleteMedia(folder, deleteFromSource: true);

        final remaining = await mediaDataSource.getMedia();
        expect(remaining.map((m) => m.id), ['keep.jpg']);
      },
      skip: macOnly,
    );

    test(
      'a delete that failed leaves the row alone',
      () async {
        final media = _media();
        await seed([media]);
        repo.failures[media.path] = 'permission denied';

        await buildViewModel().deleteMedia(media, deleteFromSource: true);

        expect(await mediaDataSource.getMedia(), hasLength(1));
      },
      skip: macOnly,
    );

    test(
      'a batch delete stops caching every item that made it',
      () async {
        final gone = _file('gone.jpg');
        final stays = _file('stays.jpg');
        await seed([gone, stays]);
        repo.failures[stays.path] = 'permission denied';

        await buildViewModel().deleteMediaBatch(
          [gone, stays],
          deleteFromSource: true,
        );

        final remaining = await mediaDataSource.getMedia();
        expect(remaining.map((m) => m.id), ['stays.jpg']);
      },
      skip: macOnly,
    );
  });

  test(
    'file delete threads the enclosing directory bookmark and moves to Trash',
    () async {
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(_media(), deleteFromSource: true);

      expect(repo.deleteFileCalls, 1);
      expect(repo.deletedFilePath, '/library/photos/image.jpg');
      expect(repo.deletedFileBookmark, 'BOOKMARK-DATA');
      expect(favoritesRepo.removedIds, contains('media-1'));

      final state = viewModel.debugState;
      expect(state, isA<FileOperationsSuccess>());
      expect((state as FileOperationsSuccess).message, 'Moved to Trash');
    },
    skip: macOnly,
  );

  test(
    'directory delete routes to deleteDirectory with the bookmark',
    () async {
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(
        _media(type: MediaType.directory),
        deleteFromSource: true,
      );

      expect(repo.deleteDirCalls, 1);
      expect(repo.deleteFileCalls, 0);
      expect(repo.deletedDirBookmark, 'BOOKMARK-DATA');

      final state = viewModel.debugState;
      expect(state, isA<FileOperationsSuccess>());
      expect(
        (state as FileOperationsSuccess).message,
        'Directory moved to Trash',
      );
    },
    skip: macOnly,
  );

  test(
    'skips favorite cleanup when the item is not favorited',
    () async {
      favoritesRepo.favorite = false;
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(_media(), deleteFromSource: true);

      expect(repo.deleteFileCalls, 1);
      expect(favoritesRepo.removedIds, isEmpty);
      expect(viewModel.debugState, isA<FileOperationsSuccess>());
    },
    skip: macOnly,
  );

  test(
    'falls back to the enclosing tracked root bookmark for a subdirectory',
    () async {
      // The subdirectory itself isn't tracked (getDirectoryById -> null), but a
      // library root at /library covers its path and holds the bookmark.
      directoryRepo = _FakeDirectoryRepository(
        const {},
        all: [
          DirectoryEntity(
            id: 'root-1',
            path: '/library',
            name: 'library',
            thumbnailPath: null,
            tagIds: const [],
            lastModified: DateTime(2020, 1, 1),
            bookmarkData: 'ROOT-BOOKMARK',
          ),
        ],
      );

      final viewModel = buildViewModel();
      final subdir = MediaEntity(
        id: 'subdir-1',
        path: '/library/photos/vacation',
        name: 'vacation',
        type: MediaType.directory,
        size: 0,
        lastModified: DateTime(2020, 1, 1),
        tagIds: const [],
        directoryId: 'subdir-1', // not a tracked directory id
      );

      await viewModel.deleteMedia(subdir, deleteFromSource: true);

      expect(repo.deleteDirCalls, 1);
      expect(repo.deletedDirPath, '/library/photos/vacation');
      expect(repo.deletedDirBookmark, 'ROOT-BOOKMARK');
    },
    skip: macOnly,
  );

  group('deleteMediaBatch', () {
    test('deletes nothing and reports every id when disabled in settings',
        () async {
      final viewModel = buildViewModel();
      final items = [_file('a.jpg'), _file('b.jpg')];

      final result = await viewModel.deleteMediaBatch(
        items,
        deleteFromSource: false,
      );

      expect(repo.deletedPaths, isEmpty);
      expect(result.hasSuccesses, isFalse);
      expect(result.failureReasons.keys, {'a.jpg', 'b.jpg'});
      expect(viewModel.debugState, isA<FileOperationsError>());
    });

    test(
      'moves every selected item to Trash with the enclosing bookmark',
      () async {
        final viewModel = buildViewModel();
        final items = [
          _file('a.jpg'),
          _file('b.jpg'),
          _directoryMedia('clips', '/library/clips'),
        ];

        final progress = <int>[];
        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
          onProgress: (completed, _) => progress.add(completed),
        );

        expect(repo.deleteFileCalls, 2);
        expect(repo.deleteDirCalls, 1);
        expect(repo.deletedFileBookmark, 'BOOKMARK-DATA');
        expect(repo.deletedDirBookmark, 'BOOKMARK-DATA');
        expect(result.successfulIds, ['a.jpg', 'b.jpg', 'clips']);
        expect(result.hasFailures, isFalse);
        expect(progress, [1, 2, 3]);
        expect(viewModel.debugState, isA<FileOperationsSuccess>());
        expect(
          (viewModel.debugState as FileOperationsSuccess).message,
          'Moved 3 items to Trash',
        );
      },
      skip: macOnly,
    );

    test(
      'trashes a selected folder once instead of its selected contents',
      () async {
        favoritesRepo.favoriteIds = {'nested.jpg'};
        final viewModel = buildViewModel();
        final items = [
          _directoryMedia('vacation', '/library/vacation'),
          _file('nested.jpg', path: '/library/vacation/nested.jpg'),
          _file('sibling.jpg'),
        ];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        // The nested file rides along with its parent: one directory delete,
        // and the only file delete is the one outside it.
        expect(repo.deleteDirCalls, 1);
        expect(repo.deleteFileCalls, 1);
        expect(repo.deletedPaths, [
          '/library/vacation',
          '/library/sibling.jpg',
        ]);
        // ...but it still counts as deleted and gets its favorite cleaned up.
        expect(
          result.successfulIds,
          containsAll(<String>['vacation', 'nested.jpg', 'sibling.jpg']),
        );
        expect(result.hasFailures, isFalse);
        expect(favoritesRepo.removedIds, ['nested.jpg']);
      },
      skip: macOnly,
    );

    test(
      'records a mid-batch failure and still deletes the rest',
      () async {
        repo.failures['/library/b.jpg'] = 'permission denied';
        final viewModel = buildViewModel();
        final items = [_file('a.jpg'), _file('b.jpg'), _file('c.jpg')];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        expect(repo.deletedPaths, ['/library/a.jpg', '/library/c.jpg']);
        expect(result.successfulIds, ['a.jpg', 'c.jpg']);
        expect(result.failureReasons.keys, ['b.jpg']);
        expect(result.failureReasons['b.jpg'], contains('permission denied'));
        expect(favoritesRepo.removedIds, isNot(contains('b.jpg')));
        expect(viewModel.debugState, isA<FileOperationsSuccess>());
        expect(
          (viewModel.debugState as FileOperationsSuccess).message,
          'Moved 2 items to Trash, 1 failed',
        );
      },
      skip: macOnly,
    );

    test(
      'nested items fail when the folder that covers them fails',
      () async {
        repo.failures['/library/vacation'] = 'permission denied';
        final viewModel = buildViewModel();
        final items = [
          _directoryMedia('vacation', '/library/vacation'),
          _file('nested.jpg', path: '/library/vacation/nested.jpg'),
        ];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        expect(repo.deletedPaths, isEmpty);
        expect(result.hasSuccesses, isFalse);
        expect(result.failureReasons.keys, containsAll(<String>[
          'vacation',
          'nested.jpg',
        ]));
        expect(favoritesRepo.removedIds, isEmpty);
        expect(viewModel.debugState, isA<FileOperationsError>());
      },
      skip: macOnly,
    );
  });

  group('transferMedia', () {
    test(
      'threads the enclosing root bookmark for both source and destination',
      () async {
        directoryRepo = _FakeDirectoryRepository({
          'dir-1': _directory(bookmarkData: 'root-bookmark'),
        });
        final viewModel = buildViewModel();

        await viewModel.transferMedia(
          _file('image.jpg'),
          destinationDirectoryPath: '/library/trips',
          mode: TransferMode.move,
        );

        expect(repo.transfers, hasLength(1));
        final transfer = repo.transfers.single;
        expect(transfer.source, '/library/image.jpg');
        expect(transfer.destination, '/library/trips');
        expect(transfer.sourceBookmark, 'root-bookmark');
        // The destination is inside the same tracked root, so that root's
        // bookmark covers it too.
        expect(transfer.destinationBookmark, 'root-bookmark');
        expect(transfer.mode, TransferMode.move);
        expect(viewModel.debugState, isA<FileOperationsTransferSuccess>());
      },
      skip: macOnly,
    );

    test(
      'prefers the bookmark handed in by the destination picker',
      () async {
        final viewModel = buildViewModel();

        await viewModel.transferMedia(
          _file('image.jpg'),
          destinationDirectoryPath: '/elsewhere',
          destinationBookmarkData: 'picked-bookmark',
          mode: TransferMode.copy,
        );

        expect(repo.transfers.single.destinationBookmark, 'picked-bookmark');
        expect(repo.transfers.single.mode, TransferMode.copy);
      },
      skip: macOnly,
    );

    test(
      'refuses a destination no bookmark covers, without touching the disk',
      () async {
        directoryRepo = _FakeDirectoryRepository({
          'dir-1': _directory(bookmarkData: 'root-bookmark'),
        });
        final viewModel = buildViewModel();

        // Outside every tracked root, and no bookmark was supplied — the sandbox
        // would reject the write, so it must not be attempted.
        await viewModel.transferMedia(
          _file('image.jpg'),
          destinationDirectoryPath: '/somewhere/untracked',
          mode: TransferMode.move,
        );

        expect(repo.transfers, isEmpty);
        expect(viewModel.debugState, isA<FileOperationsError>());
      },
      skip: macOnly,
    );

    test(
      'surfaces a taken destination as a conflict carrying the suggested name',
      () async {
        repo.conflictOnNextTransfer = '/library/trips/image.jpg';
        final viewModel = buildViewModel();

        await viewModel.transferMedia(
          _file('image.jpg'),
          destinationDirectoryPath: '/library/trips',
          destinationBookmarkData: 'bookmark',
          mode: TransferMode.move,
        );

        final state = viewModel.debugState;
        expect(state, isA<FileOperationsConflict>());
        expect(
          (state as FileOperationsConflict).suggestedPath,
          '/library/trips/image 2.jpg',
        );
        expect(repo.transfers.single.strategy, ConflictStrategy.fail);
      },
      skip: macOnly,
    );

    test(
      'retrying after a conflict asks for the keep-both rename',
      () async {
        repo.conflictOnNextTransfer = '/library/trips/image.jpg';
        final viewModel = buildViewModel();

        await viewModel.transferMedia(
          _file('image.jpg'),
          destinationDirectoryPath: '/library/trips',
          destinationBookmarkData: 'bookmark',
          mode: TransferMode.move,
          conflictStrategy: ConflictStrategy.keepBoth,
        );

        // keepBoth never conflicts: the native side renames instead of failing.
        expect(repo.transfers.single.strategy, ConflictStrategy.keepBoth);
        expect(viewModel.debugState, isA<FileOperationsTransferSuccess>());
      },
      skip: macOnly,
    );

    test('is rejected off macOS, without touching the disk', () async {
      final viewModel = buildViewModel();

      await viewModel.transferMedia(
        _file('image.jpg'),
        destinationDirectoryPath: '/library/trips',
        destinationBookmarkData: 'bookmark',
        mode: TransferMode.move,
      );

      if (Platform.isMacOS) {
        expect(viewModel.debugState, isA<FileOperationsTransferSuccess>());
      } else {
        expect(repo.transfers, isEmpty);
        expect(viewModel.debugState, isA<FileOperationsError>());
      }
    });
  });
}
